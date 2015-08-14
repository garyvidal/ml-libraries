xquery version "1.0-ml";
(:Required By Task Spawner:)
declare variable $INPUT as map:map external;
declare variable $OUTPUT as map:map external;
declare variable $PROPERTIES as map:map external;

declare variable $BOUNDARY-ELEMENTS := ("name") ! xs:QName(.); 
declare variable $STOP-PHRASE-REGEX := "(\p{P}|\p{S}|\p{N})";
declare variable $TOKENIZER := "[\s+,!;:]";
declare variable $STOP-WORDS := (("e.g.","eg","et","al", "a", "about", "above", "above", "across", "after", "afterwards", "again", "against", "all", "almost", "alone", "along", "already", "also","although","always","am","among", "amongst", "amoungst", "amount",  "an", "and", "another", "any","anyhow","anyone","anything","anyway", "anywhere", "are", "around", "as",  "at", "back","be","became", "because","become","becomes", "becoming", "been", "before", "beforehand", "behind", "being", "below", "beside", "besides", "between", "beyond", "bill", "both", "bottom","but", "by", "call", "can", "cannot", "cant", "co", "con", "could", "couldnt", "cry", "de", "describe", "detail", "do", "done", "down", "due", "during", "each", "eg", "eight", "either", "eleven","else", "elsewhere", "empty", "enough", "etc", "even", "ever", "every", "everyone", "everything", "everywhere", "except", "few", "fifteen", "fify", "fill", "find", "fire", "first", "five", "for", "former", "formerly", "forty", "found", "four", "from", "front", "full", "further", "get", "give", "go", "had", "has", "hasnt", "have", "he", "hence", "her", "here", "hereafter", "hereby", "herein", "hereupon", "hers", "herself", "him", "himself", "his", "how", "however", "hundred", "ie", "if", "in", "inc", "indeed", "interest", "into", "is", "it", "its", "itself", "keep", "last", "latter", "latterly", "least", "less", "ltd", "made", "many", "may", "me", "meanwhile", "might", "mill", "mine", "more", "moreover", "most", "mostly", "move", "much", "must", "my", "myself", "name", "namely", "neither", "never", "nevertheless", "next", "nine", "no", "nobody", "none", "noone", "nor", "not", "nothing", "now", "nowhere", "of", "off", "often", "on", "once", "one", "only", "onto", "or", "other", "others", "otherwise", "our", "ours", "ourselves", "out", "over", "own","part", "per", "perhaps", "please", "put", "rather", "re", "same", "see", "seem", "seemed", "seeming", "seems", "serious", "several", "she", "should", "show", "side", "since", "sincere", "six", "sixty", "so", "some", "somehow", "someone", "something", "sometime", "sometimes", "somewhere", "still", "such", "system", "take", "ten", "than", "that", "the", "their", "them", "themselves", "then", "thence", "there", "thereafter", "thereby", "therefore", "therein", "thereupon", "these", "they", "thick", "thin", "third", "this", "those", "though", "three", "through", "throughout", "thru", "thus", "to", "together", "too", "top", "toward", "towards", "twelve", "twenty", "two", "un", "under", "until", "up", "upon", "us", "very", "via", "was", "we", "well", "were", "what", "whatever", "when", "whence", "whenever", "where", "whereafter", "whereas", "whereby", "wherein", "whereupon", "wherever", "whether", "which", "while", "whither", "who", "whoever", "whole", "whom", "whose", "why", "will", "with", "within", "without", "would", "yet", "you", "your", "yours", "yourself", "yourselves", "the"));


(:Rehydrate the inner maps from OUTPUT:)
let $word-map := if (fn:exists(map:get($OUTPUT, 'word-map'))) then map:get($OUTPUT, 'word-map') else map:map()
let $doc-map := if (fn:exists(map:get($OUTPUT, 'doc-map'))) then map:get($OUTPUT, 'doc-map') else map:map()
let $base-query := map:get($PROPERTIES,"base-query")
let $_keys := map:keys($INPUT)
let $_ := 
    for $key in $_keys
    let $doc := fn:doc($key)

    let $words := $doc//*[fn:node-name(.) = $BOUNDARY-ELEMENTS]/fn:string(.)
                  ! fn:tokenize(.,$TOKENIZER)
                  ! fn:lower-case(.)
                  ! fn:replace(.,"^([\w]|[\w\-]|\w*\d*|\s)*","")[fn:not($STOP-WORDS = fn:lower-case(.))][fn:matches(.,"\P{Lu}")] 
    let $count := fn:count($words)

    let $procs := (1, 2, 3) !
      function ($ngram) {  
         for $i in (1 to ($count - ($count mod $ngram)))
         let $subseq := fn:subsequence($words, $i, $ngram)
         return
           if (fn:count($subseq) eq $ngram)
           then
              let $phrase := fn:lower-case(fn:string-join($subseq, " "))
              return
                if (fn:not(fn:matches($phrase, $STOP-PHRASE-REGEX)))
                then (
                    map:put($word-map, $phrase, (map:get($word-map, $phrase), 0)[1] + 1),
                    if (fn:exists(map:get($doc-map, $phrase)))
                    then ()
                    else map:put($doc-map, $phrase, 
                                 xdmp:estimate(
                                    cts:search(fn:collection(),
                                    cts:and-query((cts:and-not-query(cts:word-query($phrase), cts:document-query($key)), $base-query))))
                         ))
                else ()
            else ()
        }(.)

    return ()
(:Pass back in the doc-map and word-map:)
let $_ := (map:put($OUTPUT, 'word-map', $word-map), map:put($OUTPUT, 'doc-map', $doc-map))
return $OUTPUT
 
