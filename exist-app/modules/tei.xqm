xquery version "3.1";

(:~
 : Query library over the TEI corpus.
 :
 : This module contains no HTTP concerns and no serialisation: it returns XML or
 : maps, and the RESTXQ layer decides how to present them. Keeping the two apart
 : means the same functions serve the HTML views, the JSON API and the RDF export
 : without duplication, and they can be unit-tested without an HTTP client.
 :
 : @author Ani Chandrashekhar
 :)
module namespace tei-q = "http://madurai-tei.example.org/ns/tei";

import module namespace config = "http://madurai-tei.example.org/ns/config"
    at "config.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:~
 : List every text in the corpus with its language and title.
 : @return a sequence of maps, one per document
 :)
declare function tei-q:list-texts() as map(*)* {
    for $doc in config:corpus()/tei:TEI
    let $id := $doc/@xml:id/string()
    order by $id
    return map {
        "id": $id,
        "language": $doc/@xml:lang/string(),
        "title": normalize-space(
            ($doc//tei:titleStmt/tei:title[@type = "main"])[1]),
        "witnesses": count($doc//tei:listWit/tei:witness),
        "verses": count($doc//tei:lg[@type = "verse"])
    }
};

(:~
 : Retrieve a single TEI document by its xml:id.
 :)
declare function tei-q:text($id as xs:string) as element(tei:TEI)? {
    config:corpus()/tei:TEI[@xml:id = $id]
};

(:~
 : Retrieve one verse by its xml:id, from anywhere in the corpus.
 :)
declare function tei-q:verse($id as xs:string) as element(tei:lg)? {
    config:corpus()//tei:lg[@xml:id = $id]
};

(:~
 : Establish the reading text of an element by resolving every apparatus entry
 : to its lemma. This is the "base text" view: what the editor prints.
 :
 : Implemented as a recursive typeswitch rather than an XSLT call so that it can
 : be reused inside XQuery-only contexts such as the RDF export.
 :)
declare function tei-q:reading-text($node as node()) as xs:string {
    normalize-space(string-join(tei-q:reading-text-parts($node), ""))
};

declare %private function tei-q:reading-text-parts($node as node()) as xs:string* {
    typeswitch ($node)
        case element(tei:app) return
            (: only the lemma contributes to the reading text :)
            for $child in $node/tei:lem/node()
            return tei-q:reading-text-parts($child)
        case element(tei:witDetail) return ()
        case element(tei:note) return ()
        case element() return
            for $child in $node/node()
            return tei-q:reading-text-parts($child)
        case text() return string($node)
        default return ()
};

(:~
 : The apparatus criticus for a given element, as a sequence of maps.
 : Each entry reports the lemma, its witnesses, and the competing readings.
 :)
declare function tei-q:apparatus($context as node()) as map(*)* {
    for $app at $pos in $context//tei:app
    return map {
        "n": $pos,
        "lemma": normalize-space($app/tei:lem),
        (: array{} is required: a bare sequence of one item serialises as a JSON
           scalar rather than a one-element array, so clients would have to
           type-check every witness list. :)
        "lemma-witnesses": array { tei-q:witness-ids($app/tei:lem/@wit) },
        "readings": array {
            for $rdg in $app/tei:rdg
            return map {
                "text": normalize-space($rdg),
                "witnesses": array { tei-q:witness-ids($rdg/@wit) },
                "type": $rdg/@type/string()
            }
        },
        "notes": array {
            for $wd in $app/tei:witDetail
            return normalize-space($wd)
        }
    }
};

(:~
 : Turn a @wit attribute ("#E1 #M1") into a sequence of bare ids ("E1", "M1").
 :)
declare function tei-q:witness-ids($wit as attribute()?) as xs:string* {
    for $tok in tokenize(normalize-space($wit), "\s+")[. ne ""]
    return substring($tok, 2)
};

(:~
 : Find the verse aligned with the given verse in the other language, following
 : @corresp. Alignment is stored bidirectionally, but this function tolerates
 : one-sided encoding by searching both directions.
 :)
declare function tei-q:aligned-verses($id as xs:string) as element(tei:lg)* {
    let $source := tei-q:verse($id)
    let $forward :=
        for $ref in tokenize(normalize-space($source/@corresp), "\s+")[. ne ""]
        return tei-q:verse(substring($ref, 2))
    let $backward :=
        config:corpus()//tei:lg[
            some $r in tokenize(normalize-space(@corresp), "\s+")
            satisfies substring($r, 2) = $id
        ]
    (: The union operator, not a sequence constructor: alignment is encoded
       bidirectionally, so a verse reachable both forwards and backwards would
       otherwise be returned twice. "|" performs node-identity deduplication and
       returns the result in document order. :)
    return ($forward | $backward)
};

(:~
 : Full-text search across the corpus using the Lucene index configured in
 : collection.xconf. Returns verse-level hits with a keyword-in-context summary.
 :
 : Note that the index is language-aware: see collection.xconf for why Tamil and
 : Sanskrit fields are analysed separately.
 :)
declare function tei-q:search($term as xs:string, $lang as xs:string?) as map(*)* {
    let $hits :=
        for $lg in config:corpus()//tei:lg[ft:query(., $term)]
        where empty($lang) or $lg/ancestor::tei:TEI/@xml:lang = $lang
        order by ft:score($lg) descending
        return $lg
    return
        for $hit in $hits
        return map {
            "verse-id": $hit/@xml:id/string(),
            "text-id": $hit/ancestor::tei:TEI/@xml:id/string(),
            "language": $hit/ancestor::tei:TEI/@xml:lang/string(),
            "score": ft:score($hit),
            "reading-text": tei-q:reading-text($hit)
        }
};

(:~
 : Every named entity reference in the corpus, grouped by the authority record it
 : points at. This is what the RDF export walks.
 :)
declare function tei-q:entity-references() as map(*)* {
    let $refs := config:corpus()//(tei:placeName | tei:persName)[@ref]
    for $key in distinct-values($refs/@ref/string())
    let $group := $refs[@ref = $key]
    return map {
        "ref": $key,
        "local-id": substring-after($key, ":"),
        "count": count($group),
        "surface-forms": array {
            distinct-values($group ! normalize-space(.))
        },
        "occurrences": array {
            for $g in $group
            return map {
                "verse": ($g/ancestor::tei:lg/@xml:id/string(), "")[1],
                "text": $g/ancestor::tei:TEI/@xml:id/string()
            }
        }
    }
};
