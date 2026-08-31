xquery version "3.1";
(: Applies the Lucene index configuration before the data is loaded, so that
   documents are indexed on first ingest rather than needing a manual reindex. :)
declare variable $target external;
let $conf-col := "/db/system/config" || $target
let $mkcol :=
    if (not(xmldb:collection-available($conf-col)))
    then xmldb:create-collection("/db/system/config", substring-after($target, "/db/"))
    else ()
return
    xmldb:store-files-from-pattern($conf-col, $target, "collection.xconf")
