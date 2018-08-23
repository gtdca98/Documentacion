### Añadiremos los atributos del polígono a cada punto del centroide
from  qgis.core  import *
import sys
import processing
layer1 = "/Users/cad_salud/SACMEX/DATOS/CP_CdMx/CP_09CDMX_v4.shp"
layer2 =  "/Users/cad_salud/SACMEX/DATOS2/09m_centroids.shp"
campos = ["OBJECTID" ,"POSTALCODE" ,"ST_NAME" ,"MUN_NAME" ,"SETT_NAME","SETT_TYPE", "RECNOID", "ABREV","CVE_MUN"]
layer3 = "/Users/cad_salud/SACMEX/DATOS2//09m_centroidsCP.shp"
processing.runalg('saga:addpolygonattributestopoints', layer2, layer1, campos ,layer3)
layer = QgsVectorLayer(layer1, "caminos", "ogr")
layer.commitChanges() 
print "FIN DE PROCESO"