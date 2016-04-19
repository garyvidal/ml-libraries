xquery version "1.0-ml";

module namespace transitive = "http://marklogic.com/transitive";


import module namespace sem = "http://marklogic.com/semantics" 
    at "/MarkLogic/semantics.xqy";
declare option xdmp:mapping "false";
declare variable $DEFAULT-PARALLEL-THREADS := 4;
declare variable $THREAD-PARAM := "threads";
declare variable $CONCURRENT-PARAM := "concurrent";
declare variable $AXIS-PARAM  := "axis";

(:~
 :Takes a function and a sequence and converts the calls into a future
 xdmp:s
~:)
declare function transitive:future(
  $funct as function(*),
  $sequence as item()*,
  $threads as xs:integer
) {
  let $remainder := 
    if($sequence) then fn:count($sequence) else 0
  let $splits := 
    if($remainder) then fn:ceiling($remainder div $threads) else fn:ceiling(fn:count($sequence) div $threads)
  let $future := 
    for $s in (1 to $threads)
    let $inner-seq := fn:subsequence($sequence,(($s - 1) * $threads) + 1,$splits)
    return
      xdmp:spawn-function(
          function() {
             xdmp:lazy($inner-seq ! $funct(.))
          },
          <options xmlns="xdmp:eval">
            <priority>higher</priority>
            <result>true</result>
          </options>
     )
  return $future
};

(:~
 : Copied BFS implementation from /semantics/semantics-impl.xqy
~:)
declare function transitive:bfs(
  $s as sem:iri*, 
  $limit as xs:integer, 
  $adjV
) {
  transitive:bfs($s,$limit,$adjV,map:map())
};
(:~
 : Copied BFS implementation from /semantics/semantics-impl.xqy
~:)
declare function transitive:bfs(
  $s as sem:iri*, 
  $limit as xs:integer, 
  $adjV, 
  $options as map:map
) {
    let $visited := map:map()
    let $_ := $s ! map:put($visited, ., fn:true())
    return transitive:bfs-inner($visited, $s, $limit, $adjV)
};
(:~
 : Copied BFS implementation from /semantics/semantics-impl.xqy
~:)
declare function transitive:bfs-inner(
    $visited as map:map, 
    $queue as sem:iri*, 
    $limit as xs:integer, 
    $adjacentVertices
) {
   transitive:bfs-inner($visited,$queue,$limit,$adjacentVertices,map:map())
};
(:~
 : Copied BFS implementation from /semantics/semantics-impl.xqy
~:)
declare function transitive:bfs-inner(
    $visited as map:map, 
    $queue as sem:iri*, 
    $limit as xs:integer, 
    $adjacentVertices,
    $options as map:map
    ) {
    if (fn:empty($queue) or $limit eq 0)
    then map:keys($visited) ! sem:iri(.) (: do something with results :)
    else
        let $thingstoEnqueue :=
          if(map:get($options,$CONCURRENT-PARAM) = fn:true())
          then 
           let $func := 
             function($v) { 
               if (map:contains($visited, $v))
               then ()
               else (map:put($visited, $v, fn:true()), $v)
             }
           let $threads := (map:get($options,$THREAD-PARAM),4)[1]
           return 
              transitive:future($func, $adjacentVertices($queue),$threads)
          else 
            for $v in $adjacentVertices($queue)
            return
                if (map:contains($visited, $v))
                then ()
                else (map:put($visited, $v, fn:true()), $v)
        return transitive:bfs-inner($visited, $thingstoEnqueue, $limit - 1, $adjacentVertices,$options)
};

(:~
 : Transitively searches up the predicate s->o
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping. 
 :)
declare function transitive:transitive-down(
   $seeds as sem:iri*,
   $preds as sem:iri*, 
   $limit as xs:integer
) {
  transitive:transitive-down($seeds,$preds,$limit,cts:and-query(()))
};

(:~
 : Traverses up a relationship up subject->object via a predicate
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping. 
 :)
declare function transitive:transitive-down(
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer,
   $filter as cts:query?
) {
   transitive:bfs($seeds, $limit, function($s) { cts:triples($s,$preds,(),(),$filter) ! sem:triple-object(.) })
};

(:~
 : Traverses up a relationship up object->subject via a predicate
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping. 
 :)
declare function transitive:transitive-up(
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer
) {
   transitive:transitive-up($seeds,$preds,$limit,())
};

(:~
 : Traverses up a relationship up object->subject via a predicate
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 : @param $filter - A cts:query that will be passed as a condition of the relationship
 :)
 declare function transitive:transitive-up(
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer,
   $filter as cts:query?
) {
   transitive:bfs($seeds, $limit, function($o) { cts:triples((),$preds,$o,(),(),$filter) ! sem:triple-subject(.) })
};

(:~
 : Traverses up a relationship to find all ancestors excluding the $seed values
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 : @param $filter - A cts:query that will be passed as a condition of the relationship
 :)
declare function transitive:ancestors(  
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer
) {
   transitive:ancestors($seeds,$preds,$limit,())[fn:not((. = $seeds))]
};

(:~
 : Traverses up a relationship to find all ancestors excluding the $seed values
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 : @param $filter - A cts:query that will be passed as a condition of the relationship
 :)
declare function transitive:ancestors(  
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer,
   $filter as cts:query?
) {
   transitive:transitive-up($seeds,$preds,$limit,$filter)[fn:not((. = $seeds))]
};

(:~
 : Traverses up a relationship to find all ancestors including the $seed values
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 : @param $filter - A cts:query that will be passed as a condition of the relationship
 :)
declare function transitive:ancestors-or-self(
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer
) {
   transitive:ancestors-or-self($seeds,$preds,$limit,())
};

(:~
 : Traverses up a relationship to find all ancestors including the $seed values
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 : @param $filter - A cts:query that will be passed as a condition of the relationship
 :)
declare function transitive:ancestors-or-self(
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer,
   $filter as cts:query?
) {
 transitive:transitive-up($seeds,$preds,$limit,$filter)
};

(:~
 : Returns all descendant without seeds
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 :)
declare function transitive:descendants(  
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer
) {
   transitive:descendants($seeds,$preds,$limit,())
};
(:~
 : Returns all descendant without seeds
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 : @param $filter - A cts:query that will be passed as a condition of the relationship
 :)
declare function transitive:descendants(  
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer,
   $filter as cts:query?
) {
   transitive:transitive-down($seeds,$preds,$limit,$filter)[fn:not((. = $seeds))]
};
(:~
 : Returns all descendant with seed
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 :)
declare function transitive:descendants-or-self(  
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer
) {
   transitive:descendants-or-self($seeds,$preds,$limit,())
};
(:~
 : Returns all descendant without seeds
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 : @param $filter - A cts:query that will be passed as a condition of the relationship
 :)
declare function transitive:descendants-or-self(  
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer,
   $filter as cts:query?
) {
   transitive:transitive-down($seeds,$preds,$limit,$filter)
};

(:~
 : Returns all ancestors and descendants from a given node without the seeds
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 :)
declare function transitive:ancestors-descendants(
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer
) {(
    transitive:ancestors-descendants($seeds,$preds,$limit,())
)};
(:~
 : Returns all ancestors and descendants from a given node without the seeds
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 : @param $filter - A cts:query that will be passed as a condition of the relationship 
 :)
declare function transitive:ancestors-descendants(
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer,
   $filter as cts:query?
) {(
  transitive:transitive-up($seeds,$preds,$limit,$filter)[fn:not((. = $seeds))],
  transitive:transitive-down($seeds,$preds,$limit,$filter)[fn:not((. = $seeds))]
)};


(:~
 : Returns all ancestors and descendants from a given node and the seeds
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 :)
declare function transitive:ancestors-descendants-or-self(
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer
) {
   transitive:ancestors-descendants-or-self($seeds,$preds,$limit,())
};
(:~
 : Returns all ancestors and descendants and self from a starting seed 
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 : @param $filter - A cts:query that will be passed as a condition of the relationship
 :)
declare function transitive:ancestors-descendants-or-self(
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $limit as xs:integer,
   $filter as cts:query?
) {
(
  transitive:transitive-up($seeds,$preds,$limit,$filter),
  transitive:transitive-down($seeds,$preds,$limit,$filter)
)
};


(:~
 : Returns all Roots given a predicate.  
 : The logic is that a parent should never be the object of a given subject via a predicate
 : @param $predicates - An IRI Predicate to filter relationships by.
 :)
declare function transitive:roots($predicates as sem:iri) {
   transitive:roots($predicates,(),())
};
(:~
 : Returns all Roots given a predicate.  
 : The logic is that a parent should never be the object of a given subject via a predicate
 : @param $predicates - An IRI Predicate to filter relationships by.
 : @param $subject - a base subject if not passed will not bind subject
 :)
 declare function transitive:roots($predicates as sem:iri,$subject as sem:iri?) {
   transitive:roots($predicates,(),())
};
(:~
 : Returns 1 level deep child relationshps
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $limit - The recursive depth or degrees to traverse before stopping.
 :)
declare function transitive:children(  
   $seeds as sem:iri*,
   $preds as sem:iri*
) {
   transitive:descendants($seeds,$preds,1,())
};

(:~
 : Returns 1 level deep child relationships
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $query - Predicate Query to filter while traversing
 :)
declare function transitive:children(  
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $query as cts:query?
) {
   transitive:descendants($seeds,$preds,1,$query)
};


(:~
 : Returns 1 level up ancestor relationships
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 :)
declare function transitive:ancestor(  
   $seeds as sem:iri*,
   $preds as sem:iri*
) {
   transitive:ancestor($seeds,$preds,())
};

(:~
 : Returns 1 level up ancestor relationships
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $query - A cts:query to bind to function
 :)
declare function transitive:ancestor(  
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $query as cts:query?
) {
   transitive:ancestors($seeds,$preds,1,$query)
};

(:~
 : Returns all sibling subjects from a given node.  Logic is lookup 1 level then traverse-down
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 :)
 declare function transitive:siblings(  
   $seeds as sem:iri*,
   $preds as sem:iri*
) {
   transitive:siblings($seeds,$preds,())
};

(:~
 :  Returns all sibling subjects from a given node.  Logic is lookup 1 level then traverse-down
 : @param $seeds - The seed subject
 : @param $preds - The seed predicate
 : @param $query - A cts:query to bind to function
 :)
 declare function transitive:siblings(  
   $seeds as sem:iri*,
   $preds as sem:iri*,
   $query as cts:query?
) {
   let $parents := transitive:ancestor($seeds,$preds,$query)
   return (
     transitive:ancestors($parents,$preds,1,$query),
     transitive:descendants($parents,$preds,1,$query)
     )[fn:not((. = $seeds))]  
};

(:Transitive Extensions:)
(:~
 : Returns all Roots given a predicate.  
 : The logic is that a parent should never be the object of a given subject via a predicate
 : @param $predicates - An IRI Predicate to filter relationships by.
 : @param $subject - a base subject if not passed will not bind subject
 : @param $query - a cts:query to limit scope of roots returned
 :)
declare function transitive:roots( 
    $predicates as sem:iri,
    $subject as sem:iri?,
    $query as cts:query?
) {
 sem:sparql-values('select distinct ?subject {
    ?subject ?predicate [] .
    optional {
        ?parent ?predicate ?subject .
    }
    filter(! ?parent)
}',
 map:new((
    map:entry("predicate",$predicates),
    if($subject) then map:entry("subject",$subject) else ()
 )),
 (),
 $query
 ) ! map:get(.,"subject")
};
(:~
 :  Returns a treemap of the structure
 :)
declare function transitive:tree(
  $predicate as sem:iri
) as json:object* {
    let $roots := map:get(transitive:roots($predicate),"subject")
    return 
      transitive:traverser($roots,$predicate)
};
(:~
 : Takes a seed subject/predicate and creates a nested tree structure traversing the predicate based on a seed subject.
 :)
declare function transitive:traverser(
    $subject as sem:iri,
    $predicate as sem:iri*
) {
  transitive:traverser($subject,$predicate,())
};

(:~
 : Takes a seed subject/predicate and creates a nested tree structure traversing the predicate based on a seed subject. 
 : @param $subject - Starting Subject to traverse
 : @param $predicate - The relationship to use for the traversal
 :)
declare function transitive:traverser(
    $subject as sem:iri,
    $predicate as sem:iri*,
    $query as cts:query?
) {
   transitive:traverser($subject,$predicate,$query,map:map())
};

(:~
 : Takes a seed subject/predicate and creates a nested tree structure traversing the predicate based on a seed subject. 
 : @param $subject - Starting Subject to traverse
 : @param $predicate - The relationship to use for the traversal
 : @param $query - A cts:query to constraint all results by
 : @param $property-map - A map:map where the key is the iri and the value can be a label to replace it with.
 :  Options:
 :    map:entry("property",map:map) -  property-map(map:map) is present, the keys will be converted mapped triples. 
                                       If a string is specified as value then key  will be the value.
 :    map:entry("recursive",xs:boolean) - Determines if the traversal is recursive
 :    map:entry("maxdepth",xs:integer)  - Determines how deep to traverse before it stops 
 :                                       -1 - infinitely
 :                                        0  - Is only the current node
 :                                     * - Any depth level
 :    map:entry("callback",function(*)) - Is a callback applied to each traversed link. The callback assumes the following signature:
 :            function($node,[$options,[depth]]) {}
 :)
declare function transitive:traverser(
    $subject as sem:iri*,
    $predicate as sem:iri*,
    $query as cts:query?,
    $options as map:map?
) {
    transitive:traverser-inner($subject,$predicate,$query,$options,0)
};

(:~
 : Transitive Inner wraps traversal library and supports the recursive calls.
 : @param $subject - Is the current subject to traverse
 : @param $predicate - The relationship to use for the traversal
 : @param $query - A cts:query to constraint all results by
 : @param $options - options node as a map:map
 : @param $depth - Is the current depth of the traverser
~:)
declare function transitive:traverser-inner(
    $subject as sem:iri*,
    $predicate as sem:iri*,
    $query as cts:query?,
    $options as map:map?,
    $depth as xs:integer
) {
   (:Get Options:)
   let $recursive := (map:get($options,"recursive"),fn:true())[1]
   let $max-depth := (map:get($options,"maxdepth"),-1)[1]
   let $has-depth := if($max-depth eq -1) then fn:true() else if($depth lt $max-depth) then fn:true() else fn:false()
   let $callback  := map:get($options,"callback")
   let $yield     := map:get($options,"yield") eq fn:true()
   let $node-name := (map:get($options,"child-name"),"nodes")[1]
   (:Setter Vars:)
   let $child := 
     switch(map:get($options,$AXIS-PARAM))
     case "ancestor" return transitive:ancestors($subject,$predicate,1)
     case "sibling"  return transitive:siblings($subject,$predicate)
     default return transitive:descendants($subject,$predicate,1)
   let $jso := json:object()
   let $_ := (      
       map:put($jso,"subject",$subject),
       map:put($jso,"predicate",$predicate)
   )
   let $properties  := 
     if(fn:exists(map:get($options,"property"))) 
     then 
        let $property-map := map:get($options,"property")
        let $keys := map:keys($property-map) ! sem:iri(.)
        let $triples := cts:triples($subject,$keys)
        return
          for $triple in $triples 
          let $predicate := sem:triple-predicate($triple)
          let $label := map:get($property-map,$predicate)[. ne ""]
          let $label := if($label) then $label else $predicate
          let $object := sem:triple-object($triple)
          let $value := 
            typeswitch($object)
            case rdf:langString return fn:concat(fn:data($object),"^^@",rdf:langString-language($object))
            default return $object
          return
            map:put($jso,$label,(map:get($jso,$label),$value))
     else ()
   let $apply := 
        if(fn:exists($callback)) 
        then 
            let $arity := fn:function-arity($callback)
            return
              switch($arity)
                case 1 return $callback($jso)
                case 2 return $callback($jso,$options)
                case 3 return $callback($jso,$options,$depth)
                default return fn:error(xs:QName("CALLBACK-ARITY-MISMATCH"),"No Supported Callback interface with arity",$arity)
        else ()
   let $child-name := 
     if($node-name instance of function(*))
     then $node-name($jso)
     else $node-name 
   let $_ := 
       if($recursive and $has-depth and fn:not($yield))
       then map:put($jso,$child-name,json:to-array($child ! transitive:traverser-inner(.,$predicate,$query,$options,$depth + 1)))
       else ()
   return $jso
};
