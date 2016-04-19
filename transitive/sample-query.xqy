import module namespace transitive = "http://marklogic.com/transitive" at "/main/app/lib/transitive-library.xqy";

declare option xdmp:mapping "false";

let $skos-ns := "http://www.w3.org/2004/02/skos/core#"
let $options := map:entry("axis","descendant")
return
transitive:traverser(sem:iri("http://company/bofa"),sem:iri("http://rel#acquired"),(),$options)
