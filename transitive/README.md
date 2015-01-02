#Transitive Library
The transitive library is a collection of functions to help traverse MarkLogic (cts:triple).

###Module Namespace :
```
module namespace transitive = "http://marklogic.com/transitive"
```

##Functions:
##Axis Functions
Provides support for common xml axes paths

####transitive:ancestor()
 Returns 1 level up ancestor relationships
 ```
 function transitive:ancestor( 
 $seeds - The seed subject
 [$preds] - The seed predicate
 [$query] - A cts:query to bind to function
)
```
####transitive:ancestors()
Traverses up a relationship to find all ancestors excluding the $seed values
```
function ancestors(
  $seeds - The seed subject
  $preds - The seed predicate
  [$limit] - The recursive depth or degrees to traverse before stopping.
  [$filter] - A cts:query that will be passed as a condition of the relationship
)
```
####transitive:ancestors-or-self()
Traverses up a relationship to find all ancestors including the $seed values
```
function ancestors(
  $seeds - The seed subject
  $preds - The seed predicate
  [$limit] - The recursive depth or degrees to traverse before stopping.
  [$filter] - A cts:query that will be passed as a condition of the relationship
)
```

####transitive:ancestor-descendants()

Returns all ancestors and descendants from a given node without the seeds

```
function ancestor-descendants(
 $seeds - The seed subject
 $preds - The seed predicate
 $limit - The recursive depth or degrees to traverse before stopping.
 [$filter] - A cts:query that will be passed as a condition of the relationship 
)
```

####transitive:children()
Returns 1 level deep child relationships
```
function children(
 $seeds - The seed subject
 $preds - The seed predicate
 [$filter] - A cts:query that will be passed as a condition of the relationship 
)
```

####transitive:descendants-or-self()

Traverses down a relationship to find all descendants including the $seed values
```
function descendants-or-self(
  $seeds - The seed subject
  $preds - The seed predicate
  [$limit] - The recursive depth or degrees to traverse before stopping.
  [$filter] - A cts:query that will be passed as a condition of the relationship
)
```
####transitive:descendants()
Traverses down a relationship to find all descendants excluding the $seed values
```
function descendants(
  $seeds - The seed subject
  $preds - The seed predicate
  [$limit] - The recursive depth or degrees to traverse before stopping.
  [$filter] - A cts:query that will be passed as a condition of the relationship
)
```
####transitive:roots()
Returns all root subjects given a predicate.  The logic is that a parent should never be the object of a given subject via a predicate
```
 $predicates - An IRI Predicate to filter relationships by.
 [$subject] - a base subject if not passed will not bind subject
 [$query] - a cts:query to limit scope of roots returned
```

####transitive:siblings
```
function siblings(
  $seeds - The seed subject
  $preds - The seed predicate
  [$limit] - The recursive depth or degrees to traverse before stopping.
  [$filter] - A cts:query that will be passed as a condition of the relationship
)```

## Utility Functions

####transitive:transitive-down
Transitively searches up the predicate s->o
```
function transitive-down(
  $seeds - The seed subject
  $preds - The seed predicate
  [$limit] - The recursive depth or degrees to traverse before stopping.
  [$filter] - A cts:query that will be passed as a condition of the relationship
)```

###transitive:transitive-up
Transitively searches up the predicate o->s
```transitive-down(
  $seeds - The seed subject
  $preds - The seed predicate
  [$limit] - The recursive depth or degrees to traverse before stopping.
  [$filter] - A cts:query that will be passed as a condition of the relationship
)```


####transitive:traverser
Takes a seed subject/predicate and creates a nested tree structure traversing the predicate based on a seed subject building a nested json object
```
function transitive:traverser(
$subject - Starting Subject to traverse
$predicate - The relationship to use for the traversal
[$query] - A cts:query to constraint all results by
[$property-map] - A map:map where the key is the iri and the value can be a label to replace it with.
) as json:object 
```
#####Options Map:
The following are the options available for traverser.  This allows you ways to control how the traverser operates.

* `map:entry("property",map:map)` - Takes the key of map as the iri and adds them to the node. If a string is specified as value then key will be the value.
```xquery
  map:entry("property",map:new((
          map:entry($rdf:about,"identifier"),
          map:entry($skos:prefLabel,"prefLabel"),
          map:entry($skos:definition,"description"),
          map:entry($geo:lat,"latitude"),
          map:entry($geo:long,"longitude"),
          map:entry($geonames:countryCode,"countryCode")
  )))
```
* `map:entry("recursive",xs:boolean)` - Determines if the traversal is recursive
* `map:entry("maxdepth",xs:integer)`  - Determines how deep to traverse before it stops 
 * `-1`  infinity or will not stop till all nodes are traversed
 * `0`  Is only the current node
 * `*` Any depth level
 * `map:entry("callback",function(*))` - Is a callback applied to each traversed link. 
The callback assumes the   following signature: `function($node,[$options,[depth]]) {}`


####transitive:traverser-inner
```
 : (Internal Function)Transitive Inner wraps traversal library and supports the recursive calls.

 : @param $subject - Is the current subject to traverse
 : @param $predicate - The relationship to use for the traversal
 : @param $query - A cts:query to constraint all results by
 : @param $options - options node as a map:map
 : @param $depth - Is the current depth of the traverser
```
