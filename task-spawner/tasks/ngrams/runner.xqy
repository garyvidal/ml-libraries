xquery version "1.0-ml";

import module namespace pm  ="http://sony.com/ebookstore/model/product"
  at "/application/model/product.xqy";
  
declare namespace eb = "http://sony.com/ebookstore";

let $task-module := "/application/lib/tasks/update-ratings/task.xqy"
let $complete-module := "/application/lib/tasks/update-ratings/complete.xqy"
let $uris  := pm:calculate-product-ratings()


let $keys := map:keys($uris)
let $splits := 4
let $batchsize := if(map:count($uris) gt 0) then fn:ceiling(fn:count($keys) div $splits) else 1
return
    for $i in (1 to 4)
    let $props := map:map()
    let $_ := map:put($props,"name","update-ratings-" || $i)
    let $batch-map := map:map()
    let $start := (($i - 1) * $batchsize) + 1
    let $end   := ($i * $batchsize)
    let $_ := 
        for $uri in fn:subsequence($keys, $start,$end)
        return map:put($batch-map,$uri,map:get($uris,$uri))
    return
     if(map:count($batch-map) gt 0) then 
      try {
      xdmp:spawn("../task-spawner.xqy",
         (
          xs:QName("INPUT"),$batch-map,
          xs:QName("OUTPUT"),map:map(),
          xs:QName("TASK-PROPERTIES"),$props,
          xs:QName("TASK-MODULE"),$task-module,
          xs:QName("TASK-UOW"),500,
          xs:QName("COMPLETE-MODULE"),$complete-module,
          xs:QName("complete-options"),<options xmlns="xdmp:eval"/>,
          xs:QName("task-options"),<options xmlns="xdmp:eval"/>
         )
      )
      } catch($ex) {
        <error>{$ex}</error>/*
      } else ()