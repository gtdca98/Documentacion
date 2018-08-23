#### AjustePrjWSG84
#### script de R para ajustar la proyección de los SHP de INEGI
#### Esto permite su utilizacion en leaflet.js
library(rgdal)

### abrimos el SHP
ruta= "/RutaEnLaCualSeLocalizanLosArchivosSHP"
setwd(ruta)
### se debe escribir el SHP que se transforma (sin extensión .shp)
ogrfile = "09ent"
shapeoriginal <- readOGR(".", ogrfile)
### transformamos CRS
map_wgs84 <- spTransform(shapeoriginal, CRS("+proj=longlat +datum=WGS84"))
### guardamos el archivo
writeOGR(obj = map_wgs84, dsn = 'ruta', layer = 'CDMX', driver="ESRI Shapefile",overwrite_layer = TRUE)
### fin de proceso
### El siguiente paso consiste en usar QGIS, abrir el archivo y guardarlo como geojson.

