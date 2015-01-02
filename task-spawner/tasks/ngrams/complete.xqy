xquery version "1.0-ml";

declare variable $OUTPUT as map:map external;
declare variable $TASK-PROPERTIES as map:map external;
declare variable $REGEX := "^\{(.*)\}(\i\c*)$";

xdmp:log("Completed Update::" || fn:string(map:count($OUTPUT)))
