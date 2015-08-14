xquery version "1.0-ml";
(:This must be called from a xdmp:spawn:)
import module namespace task = "http://marklogic.com/task" at "./task.xqy";
task:_list-tasks()