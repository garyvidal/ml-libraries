# SHP File Parser

Converts a zip file containing .shp and .dbf extensions and converts to GeoJSON

```js
var geo = require("/MarkLogic/geospatial/geojson.xqy");
var zipToGeoJson = require("/lib/shape.sjs").zipToGeoJson;
var binZip = xdmp.externalBinary('c:/myshapes/NaturalGas_MarketHubs_EIA.zip');
zipToGeoJson(binZip,{});

```