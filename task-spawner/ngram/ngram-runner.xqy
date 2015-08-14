xquery version "1.0-ml";

import module namespace task = "http://marklogic.com/task" at "/task.xqy";

declare variable $task-module := "ngram-task.xqy";
declare variable $complete-module := "ngram-complete.xqy";

(:Simpled Spawned Multi-threaded mapper:)
let $base-query := cts:and-query(()) (:Filter your base:)
let $uris := cts:uris("",("map","limit=1000000"),$base-query) (:Get all URIs but could be any index value:)
let $keys := map:keys($uris) (:Get just the keys from the returned list of URIS:)
let $threads := 16 (:Split by a unit of work.  Each batch will be in increments of UOW:)
let $properties := map:map()
(:Create the Batches:)
let $splits := fn:ceiling(map:count($uris) div $threads)
let $batches := 
      for $s in (1 to $threads) 
      let $batch := map:map()
      let $_ := fn:subsequence($keys,(($s - 1) * $splits) + 1 ,$splits) ! map:put($batch,.,map:get($uris,.)) 
      return
        $batch
(:Add all properties:)
let $_ := map:put($properties,"base-query",$base-query)
for $batch at $pos in $batches
return (
      task:run(
        $task-module,
        $batch,
        100,
        <options xmlns="xdmp:eval"/>,
        map:map(),
        map:map(),
        $complete-module,
        <options xmlns="xdmp:eval"/>
     )
  )