xquery version "1.0-ml";

(:~
 : Simple Spawning Long Running Processer.  Runs task in a serial fashion for long running jobs 
 : or jobs that require enough time to complete.
 : Example Task Spawn Call:
~:)

declare namespace eval = "xdmp:eval";

(:Input a list of values to process.  You can use lexicon options to put information in the map:)
declare variable $INPUT as map:map external;

(:The return of the TASK-MODULE should be a map, this will get joined with the existing output:)
declare variable $OUTPUT as map:map external;

(:~
 : is the Task the spawner will invoke to merge the results with $OUTPUT map
 :)
declare variable $TASK-MODULE as xs:string external;
(:~
 : It is up you to pass in your options node even if it is empty.  
 : The options node will be passed to your functions for processing.
 : You can pretty much put anything you want in their  ex a job id or something.
~:)
declare variable $TASK-PROPERTIES as map:map external;

(:~
 :Module is called when there is no work left
~:)
declare variable $COMPLETE-MODULE as xs:string external;


(:~
 : Determines the number of INPUT keys to process for each iteration.  It is important that the number of tasks
 : required spawning is less than precommit-trigger depth associated with your task-server.
 : A general rule is to divide total work by 1000(max-trigger-depth)  - 10 for miscellaneous
~:)
declare variable $TASK-UOW as xs:integer external;

(:~
 : Use this options variable to pass to invoke method, like database to call etc.
~:)
declare variable $task-options as element(eval:options) external;
(:~
 : Use this options variable to pass to invoke method, like database to call etc.
~:)
declare variable $complete-options as element(eval:options) external;


(:First Check if there is anything to process in the input map
  If so then process it.
:)
if(map:count($INPUT) gt 0) then

   (:Pop the number of units from the task map, there is no order so its what is returned from keys:)
   let $keys := map:keys($INPUT)[1 to $TASK-UOW]
   let $work-map := map:map()
   let $new-output := map:map()
   let $_ := for $k in $keys return (map:put($work-map,$k,map:get($INPUT,$k)),map:delete($INPUT,$k))
   let $task-output := 
      try { 
          xdmp:invoke($TASK-MODULE,
             (
              xs:QName("TASK-INPUT"),$work-map,
              xs:QName("TASK-OUTPUT"),$OUTPUT,
              xs:QName("TASK-PROPERTIES"),$TASK-PROPERTIES
             ),
             $task-options
          )
      } catch($ex) {
          (:Handle the exception if the exception is TASK-CANCEL then exit gracefully by killing input work
            and calling COMPLETE FUNCTION
          :)
          if($ex//error:error-code = "TASK-CANCEL") 
          then (map:clear($INPUT),xdmp:log(fn:concat("Task Cancelled: ",$TASK-MODULE)))
          else xdmp:rethrow() 
      }   
   return 
   (
       (:More work keep spawning yourself :)
       xdmp:log(fn:concat("Processing Keys: ",map:count($work-map),"| TODO: ",map:count($INPUT),"| OUTPUT:",map:count($OUTPUT))),
       xdmp:spawn("task-spawner.xqy", 
          (
             xs:QName("INPUT"), $INPUT,
             xs:QName("OUTPUT"),$task-output,
             xs:QName("TASK-MODULE"),$TASK-MODULE,
             xs:QName("COMPLETE-MODULE"),$COMPLETE-MODULE,
             xs:QName("TASK-UOW"),$TASK-UOW,
             xs:QName("TASK-PROPERTIES"),$TASK-PROPERTIES,
             xs:QName("task-options"),$task-options,
             xs:QName("complete-options"),$complete-options
          )
       )
   )
        
else 
(:
 : Execute your Complete module task, 
 : say aggregate or some other fun stuff like updating a status
 :)
(  
   xdmp:log(fn:concat("Executing Complete Module:", $COMPLETE-MODULE," Output Count: ",map:count($OUTPUT))),
   if($COMPLETE-MODULE) then (
   xdmp:invoke($COMPLETE-MODULE,
      (
          xs:QName("OUTPUT"),$OUTPUT,
          xs:QName("TASK-PROPERTIES"),$TASK-PROPERTIES
      ),
      $complete-options
   ) else ()
)