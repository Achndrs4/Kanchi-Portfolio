xquery version "3.1";

(:~
 : Central configuration for the Madurai TEI application.
 :
 : Collection paths and the public base URI are defined once here. Every other
 : module imports them. Hard-coding "/db/apps/madurai-tei" across a dozen files
 : is the usual reason an eXist application cannot be deployed twice on one
 : server, for example to run a staging instance beside production.
 :
 : @author Ani Chandrashekhar
 :)
module namespace config = "http://madurai-tei.example.org/ns/config";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace repo = "http://exist-db.org/xquery/repo";
declare namespace expath = "http://expath.org/ns/pkg";

(:~ Absolute path of this application, derived at runtime rather than assumed. :)
declare variable $config:app-root :=
    let $raw := system:get-module-load-path()
    (: The load path may be prefixed with an eXist-internal URI scheme such as
       "xmldb:exist://embedded-eXist-server/db/apps/madurai-tei/modules". Take the
       substring from "/db/" onwards, then drop the trailing "/modules". :)
    let $abs :=
        if (contains($raw, "/db/"))
        then "/db/" || substring-after($raw, "/db/")
        else $raw
    return
        if (ends-with($abs, "/modules"))
        then substring($abs, 1, string-length($abs) - 8)
        else $abs;

declare variable $config:data-root := $config:app-root || "/data";
declare variable $config:texts := $config:data-root || "/texts";
declare variable $config:authority := $config:data-root || "/authority";

(:~ Public base URI for minted project identifiers. Used by the RDF serialisation. :)
declare variable $config:base-uri := "https://madurai-tei.example.org/id/";

(:~ Default number of results per page for list endpoints. :)
declare variable $config:page-size := 20;

(:~
 : All TEI documents in the corpus, excluding the authority file, which is
 : structurally TEI but is not an edition.
 :)
declare function config:corpus() as document-node()* {
    collection($config:texts)
};

declare function config:authority-doc() as document-node()? {
    doc($config:authority || "/authority.xml")
};
