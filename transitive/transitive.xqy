xquery version "1.0-ml";

module namespace transitive = "http://marklogic.com/transitive";

import module namespace semi = "http://marklogic.com/semantics/impl"
      at "/MarkLogic/semantics/sem-impl.xqy";

import module namespace sem = "http://marklogic.com/semantics" 
    at "/MarkLogic/semantics.xqy";

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
   semi:bfs($seeds, $limit, function($s) { cts:triples($s,$preds,(),(),$filter) ! sem:triple-object(.) })
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
   semi:bfs($seeds, $limit, function($o) { cts:triples((),$preds,$o,(),(),$filter) ! sem:triple-subject(.) })
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
  transitive:transitive-up($seeds,$preds,$limit,$filter)
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
   return
     transitive:children($parents,$preds,$query)[fn:not((. = $seeds))]  
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
    $subject as sem:iri,
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
    $subject as sem:iri,
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
   (:Setter Vars:)
   let $child := transitive:descendants($subject,$predicate,1)
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
   let $_ := 
       if($recursive and $has-depth and fn:not($yield))
       then map:put($jso,"nodes",json:to-array($child ! transitive:traverser-inner(.,$predicate,$query,$options,$depth + 1)))
       else ()
   return $jso
};