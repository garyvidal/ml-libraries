# SHP File Parser

Converts a zip file containing .shp and .dbf extensions and converts to GeoJSON.


**Example**

```js
var zipToGeoJson = require("/lib/shape.sjs").zipToGeoJson;
var binZip = xdmp.externalBinary('c:/myshapes/NaturalGas_MarketHubs_EIA.zip');
zipToGeoJson(binZip,{});

```

## Restrictions
* Only supports utf-8 encoded data in dbf.  MarkLogic has crude support for binary.
* Only supports EPSG:4326.  Just being lazy so will implement support using proj4js in configuration

## Attribution
Obviously I did not write all this code myself.

### Provided the dbf/shp parser logic:
*  https://github.com/gipong/shp2geojson.js
*  License : https://github.com/gipong/shp2geojson.js/blob/master/LICENSE

### Proj4js which provides coordinate mapping between different systems.
* 
* https://github.com/proj4js/proj4js
* License : https://github.com/proj4js/proj4js/blob/master/LICENSE.md

### Conversion between binary node to string
* http://stackoverflow.com/questions/8936984/uint8array-to-string-in-javascript
