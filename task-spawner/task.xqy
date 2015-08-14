xquery version "1.0-ml";

module namespace task = "http://marklogic.com/task";

declare namespace eval = "xdmp:eval";
    
declare variable $RUNNER-URI := "./task-runner.xqy";
declare variable $CANCEL-URI := "./task-cancel.xqy";
declare variable $STATUS-URI := "./task-status.xqy";
declare variable $LIST-URI   := "./task-list.xqy";


declare variable $TASK-CANCEL-KEY := "task:cancel";
declare variable $TASK-STATUS-KEY := "task:status";
declare variable $TASK-ERROR-KEY  := "task:error";
declare variable $TASK-ID-KEY     := "task:id";

declare variable $DEFAULT-UOW := 100;
declare variable $DEFAULT-EVAL-OPTIONS := <options xmlns="xdmp:eval"/>;
declare variable $DEFAULT-COMPLETE-MODULE-URI := "./task-complete.xqy";


declare function _register-state($task-id,$state) {
  xdmp:set-server-field(fn:concat($TASK-ID-KEY,$task-id),$state)
};

(:~
 Internal Function to get the canceled status you cannot call outside from appserver only task with the task-runner or you app-code
~:)
declare function _get-cancel-status($task-id) {
  xdmp:get-server-field(fn:concat($TASK-CANCEL-KEY,$task-id))
};

(:~
 : Internal function to set the cancel status
~:)
declare function _set-cancel-status($task-id) {
   xdmp:get-server-field(fn:concat($TASK-CANCEL-KEY,$task-id),fn:true())
};

(:~
 : Sets the status of the Task to Error, and set actual error
~:)
declare function _set-error-status($task-id,$error) {
  _register-state($task-id,"ERROR"),
  xdmp:set-server-field(fn:concat($TASK-ERROR-KEY,$task-id),$error)
};

declare function _get-error-status($task-id) {
  xdmp:get-server-field(fn:concat($TASK-ERROR-KEY,$task-id))
};

declare function _set-task-status($task-id,$status as map:map?) {
  xdmp:set-server-field(fn:concat($TASK-STATUS-KEY,$task-id),$status)
};

declare function _get-task-status($task-id) {
    xdmp:get-server-field(fn:concat($TASK-STATUS-KEY,$task-id))
};
declare function _task-status($task-id) {
  xdmp:get-server-field(fn:concat($TASK-STATUS-KEY,$task-id))
};
declare function _list-tasks() {
  for $field in xdmp:get-server-field-names()[fn:starts-with(.,$TASK-ID-KEY)]
  let $id     := fn:substring-after($field,$TASK-ID-KEY)
  let $status := xdmp:get-server-field($field)
  let $cancel := xdmp:get-server-field(fn:concat($TASK-CANCEL-KEY,$id))
  let $error  := xdmp:get-server-field(fn:concat($TASK-ERROR-KEY,$id))
  return
     <task>
      <id>{$id}</id>
      <cancel>{$cancel}</cancel>
      <status>{$status}</status>
      <properties>{xdmp:get-server-field(fn:concat($TASK-STATUS-KEY,$id))}</properties>
      {if($error) then <error>{$error}</error> else ()}
     </task>
};

declare function _cleanup-task($task-id) {(
  xdmp:set-server-field(fn:concat($TASK-STATUS-KEY,$task-id),()),
  xdmp:set-server-field(fn:concat($TASK-CANCEL-KEY,$task-id),()),
  xdmp:set-server-field(fn:concat($TASK-ID-KEY, $task-id),())
)};
declare function task:run(
  $task-module as xs:string,
  $task-input as map:map
) {
   task:run(
     $task-module,
     $task-input,
     $DEFAULT-UOW,
     $DEFAULT-EVAL-OPTIONS,
     map:map(),
     map:map(),
     $DEFAULT-COMPLETE-MODULE-URI,
     $DEFAULT-EVAL-OPTIONS
   )
};

declare function task:run(
  $task-module as xs:string,
  $task-input as map:map,
  $task-uow as xs:integer
) {
   task:run(
     $task-module,
     $task-input,
     $task-uow,
     $DEFAULT-EVAL-OPTIONS,
     map:map(),
     map:map(),
     $DEFAULT-COMPLETE-MODULE-URI,
     $DEFAULT-EVAL-OPTIONS
   )
};
declare function task:run(
    $task-module as xs:string,
    $task-input as map:map,
    $task-uow   as xs:integer,
    $task-options as element(eval:options),
    $properties as map:map,
    $task-output as map:map,
    $complete-module as xs:string,
    $complete-options as element(eval:options)
    
) { 
        (:Add Static Check before invoking:)
        try {
            xdmp:invoke($task-module,map:new(()),<options xmlns="xdmp:eval"><static-check>true</static-check></options>)
        }catch($ex) {
          (:fn:error(xs:QName("TASK-MODULE-COMPILE-CHECK"),"Error in Task Module " || $task-module,
          ($ex//error:format-string,
          $ex//error:datum/error:data[1]))
          :)
          xdmp:rethrow()
        },
        xdmp:spawn($RUNNER-URI, (
          xs:QName("INPUT"),           $task-input,
          xs:QName("OUTPUT"),          $task-output,
          xs:QName("TASK-MODULE"),     $task-module,
          xs:QName("TASK-UOW"),        $task-uow,
          xs:QName("TASK-OPTIONS"),    $task-options,
          xs:QName("PROPERTIES"),      $properties,
          xs:QName("COMPLETE-MODULE"), $complete-module,
          xs:QName("COMPLETE-OPTIONS"),$complete-options
         ),
         <options xmlns="xdmp:eval">
            <result>true</result>
         </options>
    )
};

(:Cancels a task :)
declare function task:cancel(
    $task-id as xs:integer
) {
     xdmp:spawn($CANCEL-URI,(
        xs:QName("TASK-ID"),$task-id
     ),
     <options xmlns="xdmp:eval">
        <result>true</result>
        <priority>higher</priority>
     </options>
    )
};

declare function task:list() {
     xdmp:spawn($LIST-URI,(),
     <options xmlns="xdmp:eval">
        <result>true</result>
        <priority>higher</priority>
     </options>
    )
};