xquery version "1.0-ml";
declare namespace eb = "http://sony.com/ebookstore";

(:~
 : Task should accept 3 variables stored in maps
~:)
declare variable $TASK-INPUT as map:map external;
declare variable $TASK-OUTPUT as map:map external;
declare variable $TASK-PROPERTIES as map:map external;
let $_ := 
for $k in map:keys($TASK-INPUT)
let $doc := cts:search(
              fn:collection("product")[eb:eBook]/element(),
              cts:element-range-query(xs:QName("eb:productId"),"=",$k,"collation=http://marklogic.com/collation/codepoint")
              ,"filtered")[eb:productId = $k]
return
  if($doc) then (
    if($doc/eb:rating) 
    then for $ra in $doc/eb:rating return xdmp:node-delete($ra) else (),
    xdmp:node-insert-child($doc,<rating xmlns="http://sony.com/ebookstore">{map:get($TASK-INPUT,$k)}</rating>)
    )
  else ()
return 
    ($TASK-OUTPUT,xdmp:log(fn:concat("Task::Updated Ratings:")))