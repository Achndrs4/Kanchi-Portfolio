xquery version "3.1";
(: Applies the Lucene index configuration before the data is loaded, so that
   documents are indexed on first ingest rather than needing a manual reindex. :)
declare variable $target external;
declare variable $home external;

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

let $conf-col := "/db/system/config" || $target
let $mkcol := local:ensure-collection("/db/system/config", tokenize($target, "/")[. != ""])
return
    xmldb:store-files-from-pattern($conf-col, $home, "collection.xconf")
