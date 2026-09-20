xquery version "3.1";

(:~
 : RESTXQ interface to the Kanchi corpus.
 :
 : Every endpoint is content-negotiable where that is meaningful: the same
 : resource is available as TEI XML, as JSON, and (for entities) as RDF/Turtle.
 : Serialisation is decided here; the data itself comes from tei.xqm.
 :
 : Design note. eXist serves these endpoints natively through RESTXQ, so no
 : external web framework is needed to publish the corpus. The Flask service in
 : services/flask does something eXist is genuinely not suited to, rather than
 : proxying what is already here. See docs/adr/0003.
 :
 : @author Ani Chandrashekhar
 :)
module namespace api = "http://kanchi.example.org/ns/api";

import module namespace config = "http://kanchi.example.org/ns/config"
    at "config.xqm";
import module namespace tei-q = "http://kanchi.example.org/ns/tei"
    at "tei.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http = "http://expath.org/ns/http-client";

(: ------------------------------------------------------------------ :)
(: Serialisation helpers                                              :)
(: ------------------------------------------------------------------ :)

declare %private function api:json($data as item()*) as item()+ {
    (
        <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="application/json; charset=utf-8"/>
                <http:header name="Access-Control-Allow-Origin" value="*"/>
            </http:response>
        </rest:response>,
        serialize($data, map {
            "method": "json",
            "indent": true()
        })
    )
};

declare %private function api:xml($data as item()*) as item()+ {
    (
        <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="application/tei+xml; charset=utf-8"/>
                <http:header name="Access-Control-Allow-Origin" value="*"/>
            </http:response>
        </rest:response>,
        $data
    )
};

declare %private function api:html($data as node()) as item()+ {
    (
        <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="text/html; charset=utf-8"/>
                <http:header name="Access-Control-Allow-Origin" value="*"/>
            </http:response>
        </rest:response>,
        $data
    )
};

declare %private function api:not-found($what as xs:string) as item()+ {
    (
        <rest:response>
            <http:response status="404">
                <http:header name="Content-Type" value="application/json; charset=utf-8"/>
            </http:response>
        </rest:response>,
        serialize(map { "error": "not found", "resource": $what },
                  map { "method": "json" })
    )
};

(: ------------------------------------------------------------------ :)
(: Service description                                                :)
(: ------------------------------------------------------------------ :)

(:~ Machine-readable list of endpoints, so the API documents itself. :)
declare
    %rest:GET
    %rest:path("/kanchi/api")
    %rest:produces("application/json")
function api:service-description() as item()+ {
    api:json(map {
        "service": "Kanchi TEI API",
        "version": "0.1.0",
        "endpoints": array {
            map { "path": "/kanchi/api/texts", "method": "GET",
                  "description": "List all texts in the corpus" },
            map { "path": "/kanchi/api/texts/{id}", "method": "GET",
                  "description": "One TEI document; Accept: application/json for metadata, "
                      || "Accept: text/html for the rendered reading view" },
            map { "path": "/kanchi/api/texts/{id}/apparatus", "method": "GET",
                  "description": "Apparatus criticus of a text" },
            map { "path": "/kanchi/api/verses/{id}", "method": "GET",
                  "description": "One verse with its reading text and apparatus" },
            map { "path": "/kanchi/api/verses/{id}/aligned", "method": "GET",
                  "description": "Verses aligned across languages" },
            map { "path": "/kanchi/api/search?q={term}&amp;lang={code}", "method": "GET",
                  "description": "Full-text search over the corpus" },
            map { "path": "/kanchi/api/entities", "method": "GET",
                  "description": "Named entities with authority alignment" },
            map { "path": "/kanchi/api/docs/{path}", "method": "GET",
                  "description": "Project documentation (docs/*.md, docs/adr/*.md), served as "
                      || "text/plain" }
        }
    })
};

(: ------------------------------------------------------------------ :)
(: Texts                                                              :)
(: ------------------------------------------------------------------ :)

declare
    %rest:GET
    %rest:path("/kanchi/api/texts")
    %rest:produces("application/json")
function api:texts() as item()+ {
    api:json(map {
        "count": count(tei-q:list-texts()),
        "texts": array { tei-q:list-texts() }
    })
};

(:~ The TEI source itself. This is the citable representation. :)
declare
    %rest:GET
    %rest:path("/kanchi/api/texts/{$id}")
    %rest:produces("application/xml", "application/tei+xml")
    %output:method("xml")
function api:text-xml($id as xs:string) as item()+ {
    let $doc := tei-q:text($id)
    return
        if (exists($doc))
        then api:xml($doc)
        else api:not-found("text/" || $id)
};

(:~ Same resource, metadata only, for clients that cannot process TEI. :)
declare
    %rest:GET
    %rest:path("/kanchi/api/texts/{$id}")
    %rest:produces("application/json")
function api:text-json($id as xs:string) as item()+ {
    let $doc := tei-q:text($id)
    return
        if (empty($doc))
        then api:not-found("text/" || $id)
        else api:json(map {
            "id": $id,
            "language": $doc/@xml:lang/string(),
            "title": normalize-space(($doc//tei:titleStmt/tei:title)[1]),
            "witnesses": array {
                for $w in $doc//tei:listWit/tei:witness
                return map {
                    "id": $w/@xml:id/string(),
                    "siglum": normalize-space($w/tei:abbr),
                    "description": normalize-space(($w/tei:desc, $w//tei:msIdentifier)[1])
                }
            },
            "verses": array {
                for $lg in $doc//tei:lg[@type = "verse"]
                return map {
                    "id": $lg/@xml:id/string(),
                    "n": $lg/@n/string(),
                    "reading-text": tei-q:reading-text($lg),
                    "apparatus-entries": count($lg//tei:app)
                }
            }
        })
};

(:~
 : The reading view: the same document run through xslt/tei-to-html.xsl, with
 : the apparatus criticus laid out beneath each verse. Chosen by content
 : negotiation, so a browser (which sends "Accept: text/html, ...") lands here
 : instead of downloading the raw TEI that api:text-xml serves to curl and API
 : clients.
 :
 : css-href/js-href are overridden to "../resources/..." rather than left at
 : the stylesheet's own defaults, because those defaults are relative to a
 : document at this exact path; the browser would otherwise resolve them
 : against ".../kanchi/api/texts/" instead of ".../kanchi/api/".
 :)
declare
    %rest:GET
    %rest:path("/kanchi/api/texts/{$id}")
    %rest:produces("text/html")
function api:text-html($id as xs:string) as item()+ {
    let $doc := tei-q:text($id)
    return
        if (empty($doc))
        then api:not-found("text/" || $id)
        else api:html(transform:transform($doc,
            doc($config:app-root || "/xslt/tei-to-html.xsl"),
            <parameters>
                <param name="css-href" value="../resources/css/kanchi.css"/>
                <param name="js-href" value="../resources/js/apparatus.js"/>
            </parameters>))
};

declare
    %rest:GET
    %rest:path("/kanchi/api/texts/{$id}/apparatus")
    %rest:produces("application/json")
function api:text-apparatus($id as xs:string) as item()+ {
    let $doc := tei-q:text($id)
    return
        if (empty($doc))
        then api:not-found("text/" || $id)
        else api:json(map {
            "text": $id,
            "entries": array { tei-q:apparatus($doc) }
        })
};

(: ------------------------------------------------------------------ :)
(: Verses                                                             :)
(: ------------------------------------------------------------------ :)

declare
    %rest:GET
    %rest:path("/kanchi/api/verses/{$id}")
    %rest:produces("application/json")
function api:verse($id as xs:string) as item()+ {
    let $lg := tei-q:verse($id)
    return
        if (empty($lg))
        then api:not-found("verse/" || $id)
        else api:json(map {
            "id": $id,
            "language": $lg/ancestor::tei:TEI/@xml:lang/string(),
            "reading-text": tei-q:reading-text($lg),
            "lines": array {
                for $l in $lg/tei:l
                return map {
                    "n": $l/@n/string(),
                    "text": tei-q:reading-text($l)
                }
            },
            "apparatus": array { tei-q:apparatus($lg) },
            "aligned": array {
                for $a in tei-q:aligned-verses($id)
                return $a/@xml:id/string()
            }
        })
};

(:~
 : Cross-language alignment. Returns the source verse beside its counterpart,
 : which is the view a philologist actually wants when comparing the Sanskrit and
 : Tamil transmissions of the same episode.
 :)
declare
    %rest:GET
    %rest:path("/kanchi/api/verses/{$id}/aligned")
    %rest:produces("application/json")
function api:verse-aligned($id as xs:string) as item()+ {
    let $source := tei-q:verse($id)
    return
        if (empty($source))
        then api:not-found("verse/" || $id)
        else api:json(map {
            "source": map {
                "id": $id,
                "language": $source/ancestor::tei:TEI/@xml:lang/string(),
                "reading-text": tei-q:reading-text($source)
            },
            "aligned": array {
                for $a in tei-q:aligned-verses($id)
                return map {
                    "id": $a/@xml:id/string(),
                    "language": $a/ancestor::tei:TEI/@xml:lang/string(),
                    "text-id": $a/ancestor::tei:TEI/@xml:id/string(),
                    "reading-text": tei-q:reading-text($a)
                }
            }
        })
};

(: ------------------------------------------------------------------ :)
(: Search                                                             :)
(: ------------------------------------------------------------------ :)

declare
    %rest:GET
    %rest:path("/kanchi/api/search")
    %rest:query-param("q", "{$q}")
    %rest:query-param("lang", "{$lang}")
    %rest:produces("application/json")
function api:search($q as xs:string*, $lang as xs:string*) as item()+ {
    if (empty($q) or normalize-space($q[1]) = "")
    then (
        <rest:response>
            <http:response status="400">
                <http:header name="Content-Type" value="application/json"/>
            </http:response>
        </rest:response>,
        serialize(map { "error": "query parameter q is required" },
                  map { "method": "json" })
    )
    else
        let $results := tei-q:search($q[1], $lang[1])
        return api:json(map {
            "query": $q[1],
            "language-filter": ($lang[1], "all")[1],
            "count": count($results),
            "results": array { $results }
        })
};

(: ------------------------------------------------------------------ :)
(: Entities and Linked Open Data                                      :)
(: ------------------------------------------------------------------ :)

declare
    %rest:GET
    %rest:path("/kanchi/api/entities")
    %rest:produces("application/json")
function api:entities() as item()+ {
    api:json(map {
        "entities": array { tei-q:entity-references() }
    })
};

(: ------------------------------------------------------------------ :)
(: Static assets for the reading view                                 :)
(: ------------------------------------------------------------------ :)

(:~
 : CSS and JS for api:text-html, served from the app's own resources
 : collection rather than relying on server-specific static-file wiring, so
 : this works the same whether eXist sits behind a reverse proxy or not.
 :)
declare %private function api:resource($doc-uri as xs:string, $media-type as xs:string) as item()+ {
    if (not(util:binary-doc-available($doc-uri)))
    then api:not-found($doc-uri)
    else (
        <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="{$media-type}"/>
            </http:response>
        </rest:response>,
        util:binary-doc($doc-uri)
    )
};

declare
    %rest:GET
    %rest:path("/kanchi/api/resources/css/kanchi.css")
    %output:method("binary")
function api:resource-css() as item()+ {
    api:resource($config:app-root || "/resources/css/kanchi.css", "text/css; charset=utf-8")
};

declare
    %rest:GET
    %rest:path("/kanchi/api/resources/js/apparatus.js")
    %output:method("binary")
function api:resource-js() as item()+ {
    api:resource($config:app-root || "/resources/js/apparatus.js", "application/javascript; charset=utf-8")
};

(:~
 : The project's own Markdown documentation (encoding-guidelines.md,
 : architecture.md, docs/adr/*.md), packaged into the .xar so that the
 : <ref target="../../docs/..."> links inside the TEI sourceDesc/notesStmt
 : resolve to something live instead of only a repo-relative path.
 :
 : $path is deliberately restricted to a single path.md or subdir/path.md
 : shape, rejecting ".." outright, since it is otherwise an attacker-controlled
 : arbitrary-file-read primitive into the app's own collection.
 :)
declare
    %rest:GET
    %rest:path("/kanchi/api/docs/{$path=.+}")
    %output:method("binary")
function api:docs($path as xs:string) as item()+ {
    if (contains($path, "..") or not(matches($path, "^[A-Za-z0-9_\-]+(/[A-Za-z0-9_\-]+)*\.md$")))
    then api:not-found("docs/" || $path)
    else api:resource($config:app-root || "/docs/" || $path, "text/plain; charset=utf-8")
};
