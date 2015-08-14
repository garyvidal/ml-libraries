xquery version "1.0-ml";

(:~
 : Simple Spawning Long Running Processer.  Runs task in a serial fashion for long running jobs 
 : or jobs that require enough time to complete.
 : Example Task Spawn Call:
~:)
import module namespace task = "http://marklogic.com/task" at "./task.xqy";

declare namespace eval = "xdmp:eval";
declare option xdmp:mapping "false";


(:Input a list of values to process.  You can use lexicon options to put information in the map:)
declare variable $INPUT as map:map external;

(:The return of the TASK-MODULE should be a map, this will get joined with the existing output:)
declare variable $OUTPUT as map:map external;

(:~
 : It is up you to pass in your options node even if it is empty.  
 : The options node will be passed to your functions for processing.
 : You can pretty much put anything you want in their  ex a job id or something.
~:)
declare variable $PROPERTIES as map:map external := map:map();

declare variable $TASK-ID     := map:get($PROPERTIES,$task:TASK-ID-KEY);
declare variable $TASK-CANCEL := map:get($PROPERTIES,$task:TASK-CANCEL-KEY);
declare variable $TASK-STATUS := map:get($PROPERTIES,$task:TASK-STATUS-KEY);

(:~
 : Determines the number of INPUT keys to process for each iteration.  It is important that the number of tasks
 : required spawning is less than precommit-trigger depth associated with your task-server.
 : A general rule is to divide total work by 1000(max-trigger-depth)  - 10 for miscellaneous
~:)
declare variable $TASK-UOW as xs:integer external;

(:~
 : is the Task the spawner will invoke to merge the results with $OUTPUT map
 :)
declare variable $TASK-MODULE as xs:string external;

(:~
 : Use this options variable to pass to invoke method, like database to call etc.
~:)
declare variable $TASK-OPTIONS as element(eval:options) external;

(:~
 :Module is called when there is no work left
~:)
declare variable $COMPLETE-MODULE as xs:string external;
(:~
 : Use this options variable to pass to invoke method, like database to call etc.
~:)
declare variable $COMPLETE-OPTIONS as element(eval:options) external;

(:Check if the task is the first-time initialized and set id then respawn and pass id back
 : If you pass in a map and share it across properties it will not register correctly
 :)
if(fn:not($TASK-ID)) then 
 let $task-id := xdmp:random()
 return (
    map:put($PROPERTIES,$task:TASK-ID-KEY,$task-id),
    task:_register-state($task-id,"STARTED")[0],
    xdmp:spawn("task-runner.xqy", (
             xs:QName("INPUT"), $INPUT,
             xs:QName("OUTPUT"),$OUTPUT,
             xs:QName("TASK-MODULE"),$TASK-MODULE,
             xs:QName("TASK-UOW"),$TASK-UOW,
             xs:QName("PROPERTIES"),$PROPERTIES,
             xs:QName("TASK-OPTIONS"),$TASK-OPTIONS,
             xs:QName("COMPLETE-MODULE"),$COMPLETE-MODULE,
             xs:QName("COMPLETE-OPTIONS"),$COMPLETE-OPTIONS
          )
     ),
     xdmp:log(fn:concat("TASK:START::[" ,$task-id ,"] Count:",map:count($INPUT))),
     $task-id
 )
else if(task:_get-cancel-status($TASK-ID)) then (
    xdmp:log(fn:concat("TASK:CANCEL::[" ,$TASK-ID ,"] ",map:count($INPUT))),
    task:_register-state($TASK-ID,"Cancelled")[0],
    task:_cleanup-task($TASK-ID)
)
(:First Check if there is anything to process in the input map:)
else if(map:count($INPUT) gt 0) then
   (:Pop the number of units from the task map, there is no order so its what is returned from keys:)
   let $keys := map:keys($INPUT)[1 to $TASK-UOW]
   let $work-map := map:map()
   let $new-output := map:map()
   let $_ := for $k in $keys return (map:put($work-map,$k,map:get($INPUT,$k)),map:delete($INPUT,$k))
   let $log := (
     map:put($PROPERTIES,"_count",(map:get($PROPERTIES,"_count"),0)[1] + 1),
     xdmp:log(fn:concat(
        "TASK:INVOKE::[" ,$TASK-ID ,"]",
       " | COUNT:",   map:count($work-map),
       " | #ITER : ", map:get($PROPERTIES,"_count"),
       " | TODO: ",   map:count($INPUT),
       " | OUTPUT:",  map:count($OUTPUT))
   ))
   let $task-output := 
      try { 
          xdmp:invoke($TASK-MODULE,
             (
              xs:QName("INPUT"),$work-map,
              xs:QName("OUTPUT"),$OUTPUT,
              xs:QName("PROPERTIES"),$PROPERTIES
             ),
             $TASK-OPTIONS
          )
      } catch($ex) {
          (:Handle the exception if the exception is TASK-CANCEL then exit gracefully by killing input work
            and calling COMPLETE FUNCTION
          :)
          if($ex//error:error-code = "TASK-CANCEL") 
          then (
            task:_register-state($TASK-ID,"CANCEL")[0],
            map:clear($INPUT),
            xdmp:log(fn:concat("TASK:CANCEL::[" ,$TASK-ID ,"] ",$TASK-MODULE))
          )
          else (
            task:_register-state($TASK-ID, "ERROR")[0],
            task:_set-error-status($TASK-ID,$ex)[0]
          )
      }   
   return 
     if(task:_task-status($TASK-ID) = ("CANCEL", "ERROR"))
     then (
        xdmp:log(fn:concat("TASK:",task:_task-status($TASK-ID), "::[" ,$TASK-ID ,"] ",map:count($work-map),"| TODO: ",map:count($INPUT),"| OUTPUT:",map:count($OUTPUT)))
     )
     else (
       (:More work keep spawning :)
       xdmp:log(fn:concat("TASK:COMPLETE::[" ,$TASK-ID ,"] ",map:count($work-map),"| TODO: ",map:count($INPUT),"| OUTPUT:",map:count($OUTPUT))),
       task:_register-state($TASK-ID,"Task")[0],
       try {
       xdmp:spawn("task-runner.xqy?id=" || fn:string(map:get($PROPERTIES,$task:TASK-ID-KEY)), 
          map:new((
            map:entry("INPUT",$INPUT),
            map:entry("OUTPUT",$OUTPUT),
            map:entry("TASK-MODULE",$TASK-MODULE),
            map:entry("COMPLETE-MODULE",$COMPLETE-MODULE),
            map:entry("TASK-UOW", $TASK-UOW),
            map:entry("PROPERTIES",$PROPERTIES),
            map:entry("TASK-OPTIONS",$TASK-OPTIONS),
            map:entry("COMPLETE-OPTIONS",$COMPLETE-OPTIONS)
          ))
       ) } catch($ex) {
        xdmp:log($ex),
        xdmp:rethrow()
       }
   )
else 
(:
 : Execute your Complete module task, 
 : say aggregate or some other fun stuff like updating a status
 :)
(  
   xdmp:log(fn:concat("TASK:COMPLETE-START::[" ,$TASK-ID ,"] ", $COMPLETE-MODULE," Output Count: ",map:count($OUTPUT))),
   task:_register-state($TASK-ID,"Completing"),
   if($COMPLETE-MODULE) then (
   xdmp:invoke($COMPLETE-MODULE,
      (
          xs:QName("OUTPUT"),$OUTPUT,
          xs:QName("PROPERTIES"),$PROPERTIES
      ),
      $COMPLETE-OPTIONS
   )) else (),
    xdmp:log(fn:concat("TASK:COMPLETE-DONE::[" ,$TASK-ID ,"] ", $COMPLETE-MODULE," Output Count: ",map:count($OUTPUT))),
   (:Perform some cleanup:)
   task:_register-state($TASK-ID,"Completed")[0],
   task:_cleanup-task($TASK-ID)
)