xquery version "1.0-ml";

declare variable $OUTPUT as map:map external;
declare variable $PROPERTIES as map:map external;
declare variable $REGEX := "^\{(.*)\}(\i\c*)$";
declare variable $TASK-ID := map:get($PROPERTIES,"task:id");
let $keys := map:keys($OUTPUT)
return
  xdmp:document-insert(
     fn:concat("/ngrams/",$TASK-ID,".xml"),
    <ngrams>{
    for $key in $keys
    let $hash := xdmp:hash64($key)
    let $values := map:get($OUTPUT,$keys)
    return
      <ngram>
        <id>{$hash}</id>
        <phrase>{$key}</phrase>
        <idf>{fn:sum($values)}</idf>
      </ngram>
    }</ngrams>
 )