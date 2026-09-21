xquery version "3.1";
(: RESTXQ registration on package install is unreliable (a long-standing
 : eXist bug: eXist-db/exist#1803, and acknowledged as such in eXist's own
 : demo-apps post-install.xql). Without this explicit call, api.xqm's
 : %rest: annotations never make it into the RESTXQ registry, so every
 : endpoint answers 405 even though the module deploys and compiles fine. :)
import module namespace xrest = "http://exquery.org/ns/restxq/exist"
    at "java:org.exist.extensions.exquery.restxq.impl.xquery.exist.ExistRestXqModule";

declare variable $target external;

xrest:register-module(xs:anyURI($target || "/modules/api.xqm"))
