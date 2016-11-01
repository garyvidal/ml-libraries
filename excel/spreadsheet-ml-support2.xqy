xquery version "1.0-ml";
(: Copyright 2009-2010 Mark Logic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)

module namespace  excel = "http://marklogic.com/openxml/excel";

declare namespace ms    = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
declare namespace r     = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
declare namespace pr    = "http://schemas.openxmlformats.org/package/2006/relationships";
declare namespace types = "http://schemas.openxmlformats.org/package/2006/content-types";
declare namespace zip   = "xdmp:zip";

declare default element namespace  "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
declare option xdmp:mapping "false";

(:version 1.0-2:)
(:
 : Precalculates all the possible column names in sequential order
 : and populates map for fast lookup
:)
declare variable $ALPHA-INDEX-MAP := 
    let $map := map:map()
    let $alpha := ("",(65 to 65+25 ) ! fn:codepoints-to-string(.))
    let $calcs := 
        for $c1 in $alpha
        for $c2 in $alpha
        for $c3 in $alpha[2 to fn:last()]
        where $c1 = "" or fn:not($c2 = "")
        return 
           ($c1 || $c2|| $c3)
    let $_ := for $col at $pos in $calcs return map:put($map,$col,$pos)
    return
      $map
;  
declare variable $INDEX-ALPHA-MAP := - $ALPHA-INDEX-MAP;
declare function excel:error($message as xs:string)
{
     fn:error(xs:QName("EXCEL-ERROR"),$message)
};

declare function excel:get-mimetype(
  $filename as xs:string
) as xs:string?
{
    xdmp:uri-content-type($filename)	
};

declare function excel:directory-uris(
  $directory as xs:string
) as xs:string*
{
    cts:uris("","document",cts:directory-query($directory,"infinity"))
};

declare function excel:directory-uris(
  $directory     as xs:string, 
  $includesheets as xs:boolean
) as xs:string*
{
    if($includesheets eq xs:boolean("true")) then
        cts:uris("","document",cts:directory-query($directory,"infinity"))
    else
        let $uris := cts:uris("","document",cts:directory-query($directory,"infinity"))
        let $finaluris :=  
                         for $uri in $uris
                         let $u := $uri
                         where  fn:not(fn:matches($uri, "sheet\d+\.xml$"))
                         return $u
        return $finaluris
     
};

declare function excel:sheet-uris(
  $directory as xs:string
) as xs:string*
{
    cts:uri-match(fn:concat($directory,"*sheet*.xml"))
};

declare function excel:workbook-sheet-names(
  $workbook as element(ms:workbook)
) as xs:string*
{
    $workbook/ms:sheets/ms:sheet/@name
};

declare function excel:sharedstring-uri(
  $directory as xs:string
)  
{
    cts:uri-match(fn:concat($directory,"*sharedStrings.xml"))
};

declare function excel:cell-string-value(
  $cells          as element(ms:c)*,
  $shared-strings as element(ms:sst)
) as xs:string*
{ 
    for $c in $cells
    return
      if ( $c/@t="s" ) then  (: using fn:string(.) instead of /text() to account for empty string :)
            $shared-strings/ms:si[fn:data($c/ms:v)+1]/ms:t/fn:string(.)
      else
	    $c/ms:v/text()
};

(: we have a convert function for this, but not sure we want to import. See Open XML Extract pipeline for details. :)
(: look at convert , spaces in names? check for dangerous chars mapped away:)
declare function excel:directory-to-filename(
  $directory as xs:string
) as xs:string
{
    let $after:= fn:substring($directory, 2)
    let $name := fn:substring-before($after,"_parts") 
    let $filename := fn:replace($name,"_",".")
    return $filename
};

declare function excel:xlsx-manifest(
  $directory as xs:string, 
  $uris      as xs:string*
) as element(zip:parts)
{
    <parts xmlns="xdmp:zip"> 
    {
      for $i in $uris
      let $dir := fn:substring-after($i,$directory)
      let $part :=  <part>{$dir}</part>
      return $part
    }
    </parts>
};

(: ====MAP SHARED================================================================================================= :)
(: Currently only maps SharedStrings, update for formulas? (within ws) or separate function ? :)

declare function excel:map-shared-strings(
  $sheet          as element(ms:worksheet), 
  $shared-strings as element(ms:sst)  
)as element(ms:worksheet)
{
    (: for $sheet in $sheets ?, check function mapping :)
    let $shared := fn:data($shared-strings//ms:t)
    let $rows := for $row at $d in $sheet//ms:row
                 let $cells  :=  for $cell at $e in $row/ms:c
                                 let $c := if(fn:data($cell/@t) eq "s") 
                                           then 
                                             element ms:c { $cell/@* except $cell/@t, attribute t{"inlineStr"}, element ms:is { element ms:t { $shared[($cell/ms:v+1 cast as xs:integer)] } } }  
                                           else
                                             $cell
                                                          
                                  return $c
                     
                 return element ms:row{ $row/@*, $cells }
                               
    let $worksheet   :=  $sheet/* except ( $sheet/ms:sheetData, $sheet/ms:tableParts, $sheet/ms:pageMargins, $sheet/ms:pageSetup, $sheet/ms:drawing)
    let $page-setup :=  $sheet/ms:pageSetup 
    let $table-parts :=  $sheet/ms:tableParts
    let $sheet-data  :=  $sheet/ms:sheetData
    let $drawing := $sheet/ms:drawing
    let $ws := element ms:worksheet {  $sheet/ms:worksheet/@*, $worksheet, element ms:sheetData{ $sheet-data/@*, $rows },  $page-setup ,$table-parts, $drawing  }
    return $ws

};

(: ============================================================================================================== :)
(: Simple Validation used by table generation :)

declare function excel:validate-child(
  $seq as node()*
) as xs:boolean
{
    fn:count(fn:distinct-values($seq/fn:local-name(child::*[1]))) eq 1 
};

(: ============================================================================================================== :)
(:   for future, pass function a (), determine file by parent element, assume given in right order :)

declare function excel:create-simple-xlsx(
  $worksheets as element(ms:worksheet)*
) as binary()
{
    let $ws-count := fn:count($worksheets)
    let $content-types := excel:content-types($ws-count,0)
    let $workbook := excel:workbook($ws-count)
    let $rels :=  excel:package-rels()
    let $workbookrels :=  excel:workbook-rels($ws-count)
    let $package := excel:xlsx-package($content-types, $workbook, $rels, $workbookrels, $worksheets)
    return $package

};

declare function excel:xlsx-package(
  $content-types as element(types:Types),
  $workbook      as element(ms:workbook),
  $rels          as element(pr:Relationships),
  $workbookrels  as element(pr:Relationships),
  $sheets        as element(ms:worksheet)*
) as binary()
{
   excel:xlsx-package($content-types, $workbook, $rels, $workbookrels, $sheets, (), (),())
};
declare function excel:xlsx-package(
  $content-types as element(types:Types),
  $workbook      as element(ms:workbook),
  $rels          as element(pr:Relationships),
  $workbookrels  as element(pr:Relationships),
  $sheets        as element(ms:worksheet)*,
  $table         as element(ms:table)*
) as binary() {
  excel:xlsx-package($content-types, $workbook, $rels, $workbookrels, $sheets, (), (),()) 
};

declare function excel:xlsx-package(
  $content-types  as element(types:Types),
  $workbook       as element(ms:workbook),
  $rels           as element(pr:Relationships),
  $workbookrels   as element(pr:Relationships),
  $sheets         as element(ms:worksheet)*,
  $worksheetrels  as element(pr:Relationships)*,
  $table          as element(ms:table)*,
  $stylesheet     as element(ms:styleSheet)?
) as binary()
{

    let $return := 
    if(   (fn:empty($worksheetrels) and fn:empty($table)) or
                          fn:not(fn:empty($worksheetrels)) and fn:not(fn:empty($table))) then   
       let $manifest := <parts xmlns="xdmp:zip">
			<part>[Content_Types].xml</part>
		 	<part>xl/workbook.xml</part>
		  <part>_rels/.rels</part>
			<part>xl/_rels/workbook.xml.rels</part>
      {
        for $i at $d in 1 to fn:count($sheets)
        let $sheet-name := fn:concat("xl/worksheets/sheet",$d,".xml")
        return <part>{$sheet-name}</part>
      }
      { 
        for $i at $d in 1 to fn:count($worksheetrels)
        let $sheet-rel-name := fn:concat("xl/worksheets/_rels/sheet", $d,".xml.rels")
        return <part>{$sheet-rel-name}</part>
      }
      {
        for $i at $d in 1 to fn:count($table)
        let $table-name :=  fn:concat("xl/tables/table",$d,".xml")
        return <part>{$table-name}</part>

      }
      {
           if(fn:exists($stylesheet))
           then <part>xl/styles.xml</part>
           else ()
      }
   </parts>
       let $parts := ($content-types, $workbook, $rels, $workbookrels, $sheets ,$worksheetrels,$table, $stylesheet) 
       return
         xdmp:zip-create($manifest, $parts)

    else excel:error("unable to create .xlsx package; $worksheetrels and $table must either both have values, or both be empty. You can't pass one without passing the other.")

    return $return 
};

declare function excel:is-number($val as xs:anyAtomicType) as xs:boolean {
	fn:not(fn:translate(fn:string($val), '0123456789.', ''))
};

(: a couple of ways to create-rows, these don't use excel:row constructor; 
   the creat-row functions don't specify row/@r or cell/@r 
   this is acceptable for opening in excel, order determines layout in sheet
:)
declare function excel:create-row(
  $values as xs:anyAtomicType*
) as element(ms:row)
{ 
    <row>
    {
           for $val at $v in $values  
           return 
(:           if (excel:is-number($val)) then     
                       <c><v>{$val}</v></c>
                  else:)
                       <c t="inlineStr"> 
                           <is>
                               <t>{$val}</t>
                           </is>
                       </c>
    }
    </row>
};
declare function excel:create-row(
  $values as xs:anyAtomicType*,
  $pos as xs:integer
) as element(ms:row)
{ 
   <row r="{$pos}" spans="1:{fn:count($values)}">
    {
           for $val at $v in $values  
           return 
             <c t="inlineStr"> 
                 <is>
                     <t>{$val}</t>
                 </is>
             </c>
    }
    </row>
};
declare function excel:create-row-r1c1(
   $cols as xs:string*,
   $row as xs:integer,
   $cellmap as map:map
) {
   excel:create-row-r1c1($cols,$row,$cellmap,map:map()) 
};

declare function excel:create-row-r1c1(
  $cols as xs:string*,
  $row as xs:integer,
  $cellmap as map:map,
  $options as map:map
) as element(ms:row) {
<row r="{$row}" spans="1:{fn:count($cols)}">{
  for $c at $pos in $cols
  let $attributes-map := 
    map:get($options,fn:concat("attributes"))
  let $attributes := 
   if($attributes-map instance of map:map) then map:get($attributes-map,fn:concat($row,":",$pos))
   else ()
  let $value := map:get($cellmap,$c)
  let $a1-ref := map:get($INDEX-ALPHA-MAP,fn:string($pos)) || $row 
  return
    if($value) then 
    <c r="{$a1-ref}" t="inlineStr"> 
        {$attributes}
        <is>
            <t>{$value}</t>
        </is>
    </c>
    else ()
 }</row>
};

declare function excel:create-row(
    $map as map:map,
    $keys as xs:string*,
    $attributes as attribute()*) as element(ms:row){
    let $row := excel:create-row($map,$keys)
    return
      <row>{
         $attributes,
         $row/node()
      }</row>
};

declare function excel:create-row-from-map(
  $map as map:map, 
  $keys as xs:string*
) as element(ms:row)
{

    (:let $cel-vals := for $i at $d in $keys
                  let $val := map:get($map,$i)
                  let $return := if(fn:empty($val)) then "" else $val ( if empty, still create cell, string ? )
                  return $return
    return excel:create-row($cel-vals):)
    excel:create-row(for $i at $d in $keys
                  let $val := map:get($map,$i)
                  let $return := if(fn:empty($val)) then "" else $val (: if empty, still create cell, string ? :)
                  return $return)
};
declare function excel:create-row-temp(
    $keys as xs:string*, 
    $values as element()*
) as element(ms:row)
{
  excel:create-row(for $k in $keys
  return $values[fn:local-name(.) eq $k]/text())
};
(: dates are stored as a julian number with an @r for id which indicates display format (applies style) :)
declare function excel:cell(
  $a1-ref as xs:string, 
  $value  as xs:anyAtomicType?
) as element(ms:c)
{
    excel:cell($a1-ref,$value,(),())              
};

declare function excel:cell(
  $a1-ref  as xs:string, 
  $value   as xs:anyAtomicType?, 
  $formula as xs:string?
) as element(ms:c)
{
    excel:cell($a1-ref,$value,$formula,())
};

declare function excel:cell(
  $a1-ref  as xs:string, 
  $value   as xs:anyAtomicType?, 
  $formula as xs:string?,
  $date-id as xs:integer?
) as element(ms:c)?
{
   if(fn:empty($value) or excel:is-number($value)) then     
        let $formula := if(fn:not(fn:empty($formula))) then 
                            <f>{$formula}</f> 
                        else ()
        let $value := if(fn:not(fn:string($value) eq "") and fn:not(fn:empty($value)) and 
                      ($value castable as xs:integer and $value ne 0)  
                        )then
                       <v>{$value}</v>
                      else ()
        return    
          element ms:c{ attribute r{$a1-ref}, 
                        if(fn:empty($date-id)) then () 
                        else attribute s{$date-id},
                        $formula, $value }
    else
              <c r="{$a1-ref}" t="inlineStr"> 
                    <is>
                        <t>{$value}</t>
                    </is>
              </c>
};

declare function excel:row(
  $cells as element(ms:c)+
) as element(ms:row)
{
    let $ids := fn:count(fn:distinct-values(excel:a1-row($cells/@r)))
    let $return := if($ids = 1) then
                                  let $ordcells := for $i in $cells 
                                                   order by excel:col-letter-to-idx(excel:a1-column($i/@r)) ascending
                                                   return $i
                                  return
                                   <row r="{excel:a1-row($cells[1]/@r)}">{$ordcells}</row>
                   else 
                      excel:error("All cells are not in the same row.  Unable to create row.")
    return $return
};

declare function excel:col-letter-to-idx(
  $letter as xs:string
) as xs:integer
{
  map:get($ALPHA-INDEX-MAP,$letter)
};

declare function excel:a1-to-r1c1(
  $a1notation as xs:string
) as xs:string
{
    let $col-index := excel:col-letter-to-idx(excel:a1-column($a1notation))
    let $row-index := excel:a1-row($a1notation)
    let $return := if(($row-index gt 1048756) or ($col-index gt 16384)) then
                       excel:error("The row and/or column index is beyond the limits of what Excel allows.")
                   else fn:concat("R",$row-index,"C",$col-index)
    return $return
};

declare function excel:r1c1-to-a1(
  $row-index as xs:integer, 
  $col-index as xs:integer
) as xs:string 
{
  (:excel has limits of 16384 for columns and 1048756 for rows :)
  (:these are limits for 2007 only, increased from 2003 :)
  (:if out of possible range, return error :)
  if (($row-index gt 1048756) or ($col-index gt 16384))
  then
    excel:error("The row and/or column index is beyond the limits of what Excel allows.")
  else

  let $col-index := $col-index - 1
  let $A := fn:string-to-codepoints("A")
  let $power1 := 26                           (: number of one-letter names :)
  let $power2 := 26 * 26                      (: number of two-letter names :)
  let $one-letter-limit := $power1            (: number of one-letter columns :)
  let $two-letter-limit := $power1 + $power2  (: number of one- and two-letter columnss :)
  return
    fn:concat(
      fn:codepoints-to-string((
        (: if three letters needed :)
        if ($col-index >= $two-letter-limit)
        then
          $A + ($col-index - $two-letter-limit) idiv $power2
        else (),
        (: if at least two letters needed :)
        if ($col-index >= $one-letter-limit)
        then
          $A + (($col-index - $one-letter-limit) mod $power2) idiv $power1
        else (),
        (: always have at least one letter :)
        $A + $col-index mod $power1
      )),
      $row-index
    )
};

declare function excel:column-width(
  $widths as xs:decimal+
) as element(ms:cols)
{  
    <cols>
    { 
        for $i at $d in $widths
        return <col min="{$d}" max="{$d}" width="{$i}" customWidth="1"/>
    }
    </cols>
};

(:option tbl-count parameter:)
declare function excel:content-types(
  $worksheet-count as xs:integer
) as element(types:Types)
{
    let $content-types := 
       <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
	<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
	<Default Extension="xml" ContentType="application/xml"/>
	<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        {
           for $i in 1 to $worksheet-count
           let $sheet-name := fn:concat("/xl/worksheets/sheet", $i,".xml" )
           return
	     <Override PartName="{$sheet-name}" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        }
       </Types>
    return $content-types
};
declare function excel:content-types(
$worksheet-count as xs:integer,
  $tbl-count as xs:integer
  ) {
   excel:content-types($worksheet-count,$tbl-count,fn:false())

};
declare function excel:content-types(
  $worksheet-count as xs:integer,
  $tbl-count as xs:integer,
  $stylesheet as xs:boolean
) as element(types:Types)
{
    let $content-types := 
       <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
	<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
	<Default Extension="xml" ContentType="application/xml"/>
	<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        {
           for $i in 1 to $worksheet-count
           let $sheet-name := fn:concat("/xl/worksheets/sheet", $i,".xml" )
           return
	     <Override PartName="{$sheet-name}" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        }
        {
            for $j in 1 to $tbl-count
            let $table-name :=  fn:concat("/xl/tables/table", $j,".xml" )
            return
                <Override PartName="{$table-name}" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml"/>
        }
        { 
           if($stylesheet) 
           then <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
           else ()}
       </Types>
    return $content-types
};

declare function excel:workbook(
  $worksheet-count as xs:integer
) as element(ms:workbook)
{
    let $workbook := 
       <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        {
          for $i at $d in 1 to $worksheet-count
          let $sheet-name := fn:concat("Sheet", $d )
          let $rId := fn:concat("rId",$d)
          return <sheet name="{$sheet-name}" sheetId="{$d}" r:id="{$rId}" />
        }
        </sheets>
       </workbook>
    return $workbook
};


declare function excel:workbook(
  $worksheet-count as xs:integer,
  $sheet-names as xs:string*
) as element(ms:workbook)
{
    let $workbook := 
       <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        {
          for $i at $d in 1 to $worksheet-count
          let $sheet-name := 
            if($sheet-names[$d]) then
              $sheet-names[$d]
            else
              fn:concat("Sheet", $d )
          let $rId := fn:concat("rId",$d)
          return <sheet name="{$sheet-name}" sheetId="{$d}" r:id="{$rId}" />
        }
        </sheets>
       </workbook>
    return $workbook
};

declare function excel:package-rels() as element(pr:Relationships)
{
    let $rels :=
       <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
	<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
       </Relationships>
    return $rels
};
(:~
 : Builds relationship document based on worksheet-count
 :)
declare function excel:workbook-rels(
  $worksheet-count as xs:integer
) as element(pr:Relationships) {
    excel:workbook-rels($worksheet-count,fn:false(),fn:false())
};
(:~
 : Builds relationship document based on worksheet-count, styles
 :)
declare function excel:workbook-rels(
  $worksheet-count as xs:integer,
  $stylesheet as xs:boolean
) as element(pr:Relationships) {
    excel:workbook-rels($worksheet-count,$stylesheet,fn:false())
};

declare function excel:workbook-rels(
  $worksheet-count as xs:integer,
  $styles as xs:boolean,
  $sharedstrings as xs:boolean
) as element(pr:Relationships)
{
    let $count := $worksheet-count
    let $workbookrels :=
         <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          {
            for $i at $d in 1 to $worksheet-count (: d redundant, STAMP OUT LET!! :)
            let $target := fn:concat("worksheets/sheet", $d,".xml")
            let $rId := fn:concat("rId",$d) 
  	        return <Relationship Id="{$rId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="{$target}"/>
          }
          {(
             if($styles) 
             then 
                <Relationship Id="rId{xdmp:set($count,$count + 1),$count}" 
                  Target="styles.xml" 
                  Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"/>
             else (),
             if($sharedstrings) 
             then <Relationship 
                Id="rId{xdmp:set($count,$count + 1),$count}" 
                Target="xl/sharedStrings.xml" 
                Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings"/>
             else ()
          )}
         </Relationships>
    return $workbookrels
};

(: will manifest as sheet1.xml.rels, sheet2.xml.rels, ... sheetN.xml.rels in .xlsx pkg:)
declare function excel:worksheet-rels(
  $start-ind as xs:integer,
  $tbl-count as xs:integer
) as element(pr:Relationships)
{
    let $worksheetrels:=
       <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        {
          for $i in 1 to $tbl-count
          let $target := fn:concat("../tables/table",($start-ind + $i - 1),".xml")
          let $id := fn:concat("rId",$i)
          return
            <Relationship Id="{$id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/table" Target="{$target}"/>
        }
       </Relationships> 
    return $worksheetrels
};
(:~
 : The current logic does not make sense for multi document.  The primary goal is to link tables to worksheet.
 :)
declare function excel:worksheet-table-rels(
  $worksheet-index as xs:integer,
  $table-index     as xs:integer
) as element(pr:Relationships)
{
    let $target := fn:concat("../tables/table",$table-index,".xml")
    let $id := fn:concat("rId",$worksheet-index)
    let $worksheetrels:=
       <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="{$id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/table" Target="{$target}"/>
       </Relationships> 
    return $worksheetrels
};

(: next go round pass in worksheet too; higher-level functions could simplify table mgmt :)
declare function excel:table(
  $table-number as xs:integer,
  $tablerange   as xs:string, 
  $column-names as xs:string+
) as element(ms:table)
{
    excel:table($table-number,$tablerange,$column-names,(),())
};

declare function excel:table(
  $table-number as xs:integer,
  $tablerange   as xs:string, 
  $column-names as xs:string+,
  $auto-filter  as xs:boolean? 
) as element(ms:table)
{
    excel:table($table-number,$tablerange,$column-names,$auto-filter,())
};

declare function excel:table(
  $table-number as xs:integer,
  $tablerange   as xs:string, 
  $column-names as xs:string+,
  $auto-filter  as xs:boolean?, 
  $style        as xs:string?
) as element(ms:table)
{
(: todo: verify range compatible with number of columns :)
(: todo: check disp-name; manifests as selectable named range in excel; @name might be required to map to table1.xml, etc. where @displayName differs for label in Excel? :)

    let $disp-name := fn:concat("Table",$table-number)
    let $id := $table-number

    let $column-count := fn:count($column-names)
    let $table-style := 
      if($style) then $style else "TableStyleLight9"
    let $table :=
      <table xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" id="{$id}" name="{$disp-name}" displayName="{$disp-name}" ref="{$tablerange}"  totalsRowShown="0" >
         {
             if(fn:empty($auto-filter) or $auto-filter) then
             <autoFilter ref="{$tablerange}"/>
             else 
              () 
         }
             <tableColumns count="{$column-count}"> 
         {
               for $i at $d in $column-names
               return <tableColumn id="{$d}" name="{$i}"/>
         }
             </tableColumns>
         {
         if($style) then 
             <tableStyleInfo name="{$table-style}" showFirstColumn="0" showLastColumn="0" showRowStripes="1" showColumnStripes="0"/>
         else ()
         }
      </table>
    return $table
};

(: optional col-widths, tbl-count parameters :)
declare function excel:worksheet(
  $rows as element(ms:row)*
) as element(ms:worksheet)
{
    excel:worksheet($rows,(),())
};

declare function excel:worksheet(
  $rows      as element(ms:row)*,
  $colwidths as element(ms:cols)*
) as element(ms:worksheet)
{
    excel:worksheet($rows,$colwidths,())
};

declare function excel:worksheet(
  $rows      as element(ms:row)*,
  $colwidths as element(ms:cols)?,
  $tbl-count as xs:integer?
) as element(ms:worksheet)
{
    let $sheet := <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
                      {
                       if(fn:not(fn:empty($colwidths))) then
                           $colwidths
                       else
                           ()
                      } 
                      <sheetData>
                      { 
                        ($rows) 
                      }
                      </sheetData>
                      {
                        if(fn:not(fn:empty($tbl-count)) and $tbl-count  gt 0) then
                          <tableParts count="{$tbl-count}">
                           {
                            for $i in 1 to $tbl-count
                            let $id := fn:concat("rId",$i)
                            return 
                                <tablePart r:id="{$id}" />
                           }
                          </tableParts>
                        else () 
                      }
                  </worksheet>
    return $sheet
};
declare function excel:worksheet-multi(
  $rows      as element(ms:row)*,
  $colwidths as element(ms:cols)?,
  $table-index as xs:integer?
) as element(ms:worksheet)
{
    let $sheet := <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
                      {
                       if(fn:not(fn:empty($colwidths))) then
                           $colwidths
                       else
                           ()
                      } 
                      <sheetData>
                      { 
                        ($rows) 
                      }
                      </sheetData>
                      {
                        if(fn:not(fn:empty($table-index)) and $table-index  gt 0) then
                          <tableParts count="1">
                           {
                            let $id := fn:concat("rId",$table-index)
                            return 
                                <tablePart r:id="{$id}" />
                           }
                          </tableParts>
                        else () 
                      }
                  </worksheet>
    return $sheet
};
(:utility functions to grab Column or Row from "A1" notation :)
declare function excel:a1-row(
  $a1 as xs:string
) as xs:integer
{
      xs:integer(fn:replace($a1,("[A-Z]+"),""))
};

declare function excel:a1-column(
  $a1 as xs:string 
)as xs:string
{
       fn:replace($a1,("\d+"),"")
};

(:     functions related set-cells       :)
declare function excel:passthru-workbook($x as node(), $newSheetData as element(ms:sheetData)) as node()*
{
   for $i in $x/node() return excel:wb-set-sheetdata($i,$newSheetData)
};

declare function excel:wb-set-sheetdata($x as node(), $newSheetData as element(ms:sheetData)) as node()*
{
 
   typeswitch($x)
     case text() return $x
     case document-node() return document {$x/@*,excel:passthru-workbook($x,$newSheetData)}
     case element(ms:sheetData) return  $newSheetData
     case element() return  element{fn:name($x)} {$x/@*,excel:passthru-workbook($x,$newSheetData)}
     default return $x

};

declare function excel:set-cells(
  $v_sheet as element(ms:worksheet), 
  $cells as element(ms:c)*
) as element(ms:worksheet)
{   
    let $sheetDataTst := $v_sheet//ms:sheetData
    let $sheet := if(fn:empty($sheetDataTst/*)) then 
                        let $row := excel:row(excel:cell("A1",""))
                        let $tmpSheet := excel:worksheet($row)
                        return excel:wb-set-sheetdata($v_sheet, $tmpSheet//ms:sheetData) 
                 else $v_sheet

    let $sheetData := $sheet/ms:sheetData

    let $cel-rows := fn:distinct-values(excel:a1-row($cells/@r))
    let $orig-rows := $sheetData/ms:row
   
    (:determine missng rows, stub out rows that don't exist so we can loop through rows and add cells accordingly :) 
    let $mssing := 
                    for $i in $cel-rows
                    let $x := if(fn:exists($orig-rows[@r=$i])) then () else 
                              let $a1 := fn:concat("A",$i)
                              return excel:row(excel:cell($a1,""))
                    return $x

    let $both := (($orig-rows,$mssing))
   
    (:want to keep rows in order :) 
    let $ord-rows := for $i in $both
                     order by xs:integer($i/@r) ascending  
                     return $i
                               
    let $new-rows :=  for $r in $ord-rows
                      let $cells-to-add := for $i in $cells
                                           let $c := $i where (excel:a1-row($i/@r) = $r/@r)
                                           return $c
                      let $orig-cells := $r/ms:c

                      (:now must replace any cells that previous exist:)
                      (: want to eliminate cells that we're replacing, so update cells to only return delta, then merge the two sequences:)

                      let $upd-cells := for $i in $orig-cells
                                        let $x := if(fn:exists($cells-to-add[@r=$i/@r])) 
                                        then () else $i
                                        return $x
                      
                      (:now that we have all cells, order, return row:)
                      let $all-cells2 := ($cells-to-add, $upd-cells)
                      let $all-ord-cells := for $ce in $all-cells2
                                            order by excel:col-letter-to-idx(excel:a1-column($ce/@r)) ascending
                                            return $ce


                      return  element ms:row{ $r/@* , ($r/* except $r/ms:c), $all-ord-cells}

    (:set the updated rows in sheetData, set sheetData in worksheet, return worksheet:)
    let $newSheetData := element ms:sheetData { $sheetData/@*, $new-rows }
    let $final-sheet := excel:wb-set-sheetdata($sheet, $newSheetData)
    return $final-sheet
                    
};

(: calendar conversion functions   :)
declare function excel:julian-to-gregorian(
  $excel-julian-day as xs:integer
) as xs:date
{
   (: formula from http://quasar.as.utexas.edu/BillInfo/JulianDatesG.html :)
   (: adapted for excel :)
   (: won't calculate for years < 400 :)
   let $JD :=  $excel-julian-day - 2 +2415020.5 
   let $Z :=  $JD+0.5
   let $W := fn:floor(($Z - 1867216.25) div 36524.25)
   let $X := fn:floor($W div 4)
   let $A := $Z + 1 + $W - $X
   let $B := $A+1524
   let $C := fn:floor(( $B - 122.1) div 365.25)
   let $D := fn:floor(365.25 * $C)
   let $E := fn:floor(($B - $D) div 30.6001)
   let $F := fn:floor(30.6001 * $E)
   let $day  := $B - $D - $F
   let $month := if($E < 13.5) then ($E - 1) else ($E - 13)
   let $year := if($E <=2) then $C - 4715 else $C - 4716
   let $finday := if(fn:string-length($day cast as xs:string) eq 1) then fn:concat("0",$day) else $day
   let $finmonth := if(fn:string-length($month cast as xs:string) eq 1) then fn:concat("0",$month) else $month
   let $findate := fn:concat($year,"-", $finmonth, "-",$finday)

   (: return  ($day, $month, $year) :)
(: return as xs:date :)
   return   xs:date($findate)
};

(:function that's inverse of above :)
declare function excel:gregorian-to-julian(
  $date   as xs:date
) as xs:integer
{
   let $year := fn:year-from-date($date)
   let $month := fn:month-from-date($date)
   let $day := fn:day-from-date($date)
   (: formula from http://quasar.as.utexas.edu/BillInfo/JulianDatesG.html :)
   (: adapted for excel :)
   let $NY := if($year le 2) then $year + 1 else $year
   let $NM := if($year le 2) then $month + 12 else $month
   let $A := fn:floor($NY div 100)
   let $B :=  fn:floor($A div 4)
   let $C := (2 - $A + $B)
   let $E := fn:floor(365.25 * ( $NY + 4716))
   let $F := fn:floor(30.6001 * ($NM + 1))
   let $NJD := $C + $day + $E + $F - 1524.5 - 2415020.5 + 2 
   return $NJD
};

(:rename width; optional colcustwidth and tabstyle params :)

declare function excel:create-xlsx-from-xml-table(
$xmltable as node()
) as binary()?
{
    create-xlsx-from-xml-table($xmltable,(),())
};

declare function excel:create-xlsx-from-xml-table(
$xmltable as node(),
$colcustwidth as xs:decimal?
) as binary()?
{
    create-xlsx-from-xml-table($xmltable,$colcustwidth,()) 
};

declare function excel:create-xlsx-from-xml-table(
$xmltable as node(),
$colcustwidth as xs:decimal?,
$auto-filter as xs:boolean?
) as binary()?
{
    create-xlsx-from-xml-table($xmltable,$colcustwidth, $auto-filter, ()) 
};


declare function excel:create-xlsx-from-xml-table(
    $xmltable as node(),
    $colcustwidth as xs:decimal*,
    $auto-filter as xs:boolean?,
    $tabstyle as xs:boolean?
) as binary()?
{
	let $sheet-name :=
		fn:string($xmltable/@name)
		
	let $headers :=
		$xmltable/*:header/child::*

	let $body :=
		if ($xmltable/*:body) 
		then $xmltable/*:body/child::*
		else if($headers) 
		  then fn:subsequence($xmltable/child::*,2)
		  else $xmltable/child::*
			
	(: derive column names and order from local-names of cell
	 : elements from first row, if column 
	 :)
	let $element-names :=
	  if($headers) then 
		for $column at $pos in $headers
		let $name := fn:local-name($column)
		return 
	        $name
      else 
	    for $column at $pos in ($body)[1]/child::*
	    let $name := fn:local-name($column)
		return 
			$name
     let $header-count :=  1
	(: put cells of each row in a map:map using local-name as key to anticipate
	 : inconsistent order. $element-names determines order.
	 :)
	let $body-rows := 
		for $r at $pos in $body
		let $values := json:object()
		let $cells :=
			(: warning: doesnt handle duplicate names properly (these are not expected!) :)
			for $c in $r/child::*
			let $value := (fn:string($c)," ")[1]
			return
				map:put($values, fn:local-name($c), $value)
		return
			excel:create-row-r1c1($element-names,$pos + $header-count,$values)

	(: Important note: Column names *must* be unique, otherwise the file wont open in Excel! :)
	let $column-names :=
		if ($headers) then
			for $column in $headers
			return 
				fn:string($column)
		else
			$element-names
	
	let $header-rows := excel:create-row($column-names,1)	
	let $content-types := excel:content-types(1,1)
	let $workbook := 
	   if($sheet-name) 
	   then excel:workbook(1,$sheet-name)
	   else excel:workbook(1)
	let $rels :=  excel:package-rels()
	let $workbookrels :=  excel:workbook-rels(1)

	let $headers-count := fn:count(1)
	let $row-count     := fn:count(( $body-rows))
	let $column-count  := fn:count($column-names)

	let $tablerange := fn:concat(excel:r1c1-to-a1($headers-count, 1), ":", excel:r1c1-to-a1($headers-count + $row-count, $column-count))
    
	let $table :=
		if ($tabstyle or $auto-filter) then
			excel:table(1, $tablerange, $column-names, $auto-filter, $tabstyle)
		else ()

	let $worksheetrels :=
		if ($tabstyle or $auto-filter) then
			excel:worksheet-rels(1,1)
        else ()

	let $col-widths :=
		if (fn:count($colcustwidth) eq 1) then
			for $i in 1 to $column-count
			return
				xs:decimal($colcustwidth)
	    else if(fn:count($colcustwidth) gt 1) then $colcustwidth ! xs:decimal(.)
		else 20.0
		
	let $col-widths :=
		if ($col-widths) then
			excel:column-width($col-widths) 
		else ()

	let $tbl-count := if ($tabstyle or $auto-filter) then 1 else ()
	let $sheet1 := excel:worksheet(($header-rows[./*],$body-rows), $col-widths, $tbl-count)

	let $package := excel:xlsx-package($content-types, $workbook, $rels, $workbookrels, $sheet1, $worksheetrels, $table,())
	return $package
};

declare function excel:create-xlsx-from-xml-tables(
  $xmltables as node()*,
  $options as map:map
) {
  (:Get Options We want to parse:)
  let $table-style := map:get($options,"tablestyle")
  let $auto-filter := map:get($options,"autofilter")
  
  let $sheet-names :=
  	    if($xmltables/@name) 
  	    then for $xmltable in $xmltables return $xmltable/@name/xs:string(.)
  	    else map:get($options,"sheetnames")
  let $sheet-count := fn:count($sheet-names)
  let $workbook := 
  	   if($sheet-names) 
  	   then excel:workbook($sheet-count,$sheet-names)
  	   else excel:workbook($sheet-count)
  let $rels :=  excel:package-rels()
  let $stylesheet := map:get($options,"stylesheet")
  let $content-types := excel:content-types($sheet-count,$sheet-count,fn:exists($stylesheet))
  let $workbookrels :=  excel:workbook-rels($sheet-count,fn:exists($stylesheet)) 
  let $sheet-tables := ()
  let $sheet-rels   := ()
  let $sheet-data := 
        for $xmltable at $table-pos in $xmltables
        let $sheet-name := 
            ($sheet-names[$table-pos],$xmltable/@name)[1]
      	let $headers :=
      		$xmltable/*:header/child::*
      	let $body :=
      		if ($xmltable/*:body) 
      		then $xmltable/*:body/child::*
      		else if($headers) 
      		  then fn:subsequence($xmltable/child::*,2)
      		  else $xmltable/child::*

      	(: derive column names and order from local-names of cell
      	 : elements from first row, if column 
      	 :)
      	let $element-names :=
      	  if($headers) then 
      		for $column at $pos in $headers
      		let $name := fn:local-name($column)
      		return 
      	        $name
            else 
      	    for $column at $pos in ($body)[1]/child::*
      	    let $name := fn:local-name($column)
      		return 
      			$name
           let $header-count :=  1
      	(: put cells of each row in a map:map using local-name as key to anticipate
      	 : inconsistent order. $element-names determines order.
      	 :)
      	let $body-rows := 
      		for $r at $pos in $body
      		let $values := json:object()
      		let $cells :=
      			(: warning: doesnt handle duplicate names properly (these are not expected!) :)
      			for $c in $r/child::*
      			let $value := (fn:string($c)," ")[1]
      			return
      				map:put($values, fn:local-name($c), $value)
      		return
      			excel:create-row-r1c1($element-names,$pos + $header-count,$values,$options)
      
      	(: Important note: Column names *must* be unique, otherwise the file wont open in Excel! :)
      	let $column-names :=
      		if ($headers) then
      			for $column in $headers
      			return 
      				fn:string($column)
      		else
      			$element-names      	
      	let $header-rows := excel:create-row($column-names,1)	
      	let $headers-count := fn:count(1)
      	let $row-count     := fn:count($body-rows)
      	let $column-count  := fn:count($column-names)
      	let $tablerange := fn:concat(excel:r1c1-to-a1($headers-count, 1), ":", excel:r1c1-to-a1($headers-count + $row-count, $column-count))
        let $colcustwidth := (map:get($options,$sheet-name || ":colWidths"),20)
      	let $col-widths :=
      		if (fn:count($colcustwidth) eq 1) then
      			for $i in 1 to $column-count
      			return
      				xs:decimal($colcustwidth)
      	    else if(fn:count($colcustwidth) gt 1) then $colcustwidth ! xs:decimal(.)
      		else 20.0
      		
      	let $col-widths :=
      		if ($col-widths) then
      			excel:column-width($col-widths) 
      		else ()
        
       (:Map Table Styles from override:)
        let $tabstyle := 
	       if(map:contains($options,$sheet-name || ":tablestyle"))
	       then map:get($options,$sheet-name || ":tablestyle")
	       else $table-style
	    let $autofilter := 
	       if(map:contains($options,$sheet-name || ":autofilter"))
	       then map:get($options,$sheet-name || ":autofilter")
	       else $auto-filter
	       
      	let $tbl-count := if ($tabstyle or $auto-filter) then 1 else ()
        let $table :=
    		if ($tabstyle or $auto-filter) then
    			excel:table($table-pos, $tablerange, $column-names, $autofilter, $tabstyle)
    		else ()
        let $worksheet-rel :=
             if ($tabstyle or $autofilter) 
             then excel:worksheet-table-rels($table-pos,$table-pos)
             else ()
      	return (
      	    excel:worksheet-multi(($header-rows[./*],$body-rows), $col-widths, $table-pos),
      	    xdmp:set($sheet-tables,($sheet-tables,$table)),
      	    xdmp:set($sheet-rels,($sheet-rels,$worksheet-rel))
      	)

  let $package := 
    excel:xlsx-package(
        $content-types, 
        $workbook, 
        $rels, 
        $workbookrels, 
        $sheet-data, 
        $sheet-rels, 
        $sheet-tables,
        $stylesheet)
  return 
     $package
};

