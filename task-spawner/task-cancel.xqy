xquery version "1.0-ml";

import module namespace task = "http://marklogic.com/task" at "/lib/task-spawner/task.xqy";

declare variable $TASK-ID as xs:integer external;

(:
xdmp:set-server-field(fn:concat($task:TASK-CANCEL-KEY,$TASK-ID),fn:true())
:)

(:
to cancel tasks in the task-runner
:)
task:_set-cancel-status($TASK-ID)