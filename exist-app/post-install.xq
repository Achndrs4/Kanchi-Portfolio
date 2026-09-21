xquery version "3.1";
(: RESTXQ registration on package install is unreliable (a long-standing
 : eXist bug: eXist-db/exist#1803, and acknowledged as such in eXist's own
 : demo-apps post-install.xql). Without this explicit call, api.xqm's
 : %rest: annotations never make it into the RESTXQ registry, so every
 : endpoint answers 405 even though the module deploys and compiles fine. :)
import module namespace xrest = "http://exquery.org/ns/restxq/exist"
    at "java:org.exist.extensions.exquery.restxq.impl.xquery.exist.ExistRestXqModule";

declare variable $target external;

(:~ create-collection only reliably creates one segment at a time in this
 : eXist version, so walk the path and create each missing segment in turn
 : rather than passing it a multi-segment name in one call. :)
declare function local:ensure-collection($parent as xs:string, $segments as xs:string*) as empty-sequence() {
    if (empty($segments))
    then ()
    else
        let $path := $parent || "/" || head($segments)
        let $create :=
            if (not(xmldb:collection-available($path)))
            then xmldb:create-collection($parent, head($segments))
            else ()
        return local:ensure-collection($path, tail($segments))
};

(: The Lucene index configuration (collection.xconf) is deployed as ordinary
 : app content at $target/collection.xconf, same as every other file in the
 : package -- but eXist only applies a collection.xconf that lives under
 : /db/system/config/<matching-path>, so it must be copied there explicitly.
 :
 : This runs here in <finish>, not in <prepare>: a <prepare> script receives
 : $home as the package's extraction directory on some eXist deployment
 : paths, but under Docker autodeploy $home resolves to eXist's own install
 : root rather than anything containing this package's files, so
 : xmldb:store-files-from-pattern($conf-col, $home, "collection.xconf")
 : silently copied nothing there. Reading the file back out of $target
 : instead -- after it has actually been deployed -- needs no filesystem
 : access at all, so it isn't sensitive to how the package was unpacked.
 :
 : Consequence: the data is already stored by the time this config takes
 : effect, so the initial ingest bypassed indexing -- an explicit reindex
 : is required to make the full-text index usable immediately rather than
 : only after the next edit to the collection.
 :
 : The copy has to go through xmldb:store(), not xmldb:copy-resource(): a
 : copy clones the document without going through the store pipeline that
 : notifies eXist's CollectionConfigurationManager, so the index config
 : would sit there unapplied until *something else* touched the collection
 : (confirmed by hand against a running instance -- copy-resource left
 : ft:query matching nothing even after an explicit reindex, and switching
 : to store()+reindex fixed it immediately). :)
let $conf-col := "/db/system/config" || $target
let $mkcol := local:ensure-collection("/db/system/config", tokenize($target, "/")[. != ""])
let $store-conf := xmldb:store($conf-col, "collection.xconf", doc($target || "/collection.xconf"))
let $reindex := xmldb:reindex($target)
return
    xrest:register-module(xs:anyURI($target || "/modules/api.xqm"))
