## Generación de datos

### Fuentes

El sistema se apoya en dos grandes grupos de información:

- Información publica descargada directamete del INEGI, Servicio Postal Mexicano y bases de datos abiertas  

- Información agregada relativa al consumo de agua, procesada a partir de la emisión de boletas de agua de SACMEX.

Puede consultar con detalle el [listado de fuentes](DlistaFuentes.md) 

<hr>

### Herramientas

El procesamiento de la información requiere de dos applicaciones:

Procesamiento estadístico de datos (open source data analysis software) [R-studio](https://www.rstudio.com/products/RStudio/ "Open Source edition. integrated development environment (IDE) for R ")  

Procesamiento de Información geoespacial (GIS application) [Qgis 2.1](https://qgis.org/en/site/ "A Free and Open Source Geographic Information System ")  

<hr>

### Datos Generados

#### CDMX.js

Archivo que contiene información en formato GEOJSON relativo a las coordenadas que conforman el polígono estatal de la  Ciudad de México

Toda la información geoespacial se integra en el sistema dentro de la variable **CDMX**.

La generación de este archivo se incluye en el script R **CodigoDatos.R**

Puede consultar el [esquema](/Docs/images/DCDMX.png) y el [detalle-guía](/Docs/Gen_CDMX.md) del procesamiento.


#### munCDMX.geojson.js

Archivo que contiene información en formato GEOJSON relativo a las  coordenadas que conforman los polígonos de las delegaciones de la Ciudad de México

Toda la información geoespacial se integra en el sistema dentro de la variable **munCDMX**.

La generación de este archivo se  incluye en el script R **CodigoDatos.R**

Puede consultar el  [esquema](/Docs/images/DMUNCDMX.png) y el [detalle-guía](/Docs/Gen_munCDMX.md) del procesamiento.


#### DataRetoH2Obis.geojson.js

Archivo que contiene información en formato GEOJSON relativo a: 

1) Las coordenadas que conforman los polígonos de las colonias identificadas para la Ciudad de México y, 

2) Los datos demográficos y de consumo de agua por colonia.

Toda la información geoespacial se integra en el sistema dentro de la variable **colCDMX** .

Puede consultar el [esquema](/Docs/images/DRH2O_1.png), el [conjunto de datos](/Docs/images/DRH2O_2.png) y el [detalle-guía](/Docs/Gen_RH2O.md) del procesamiento.   

La generación de este archivo se realiza mediante 2 scrips:

a)  Script R **CodigoDatos.R**

b)  Script python en la consula de QGIS 2.1 **CodigoDatos.py**   


#### col_CP.js

Listado  -arreglo javascript- correspondiente las colonias identificadas para la Ciudad de México 

El listado se integra en el sistema dentro de la variable **listacol**.

Puede consultar el [esquema](/Docs/images/DCOLCP.png) y el [detalle-guía](/Docs/Gen_COLCP.md) del procesamiento.

La generación de este archivo se  incluye en el script R **CodigoDatos.R**      


#### emision_referencia.js

Listado  -arreglo javascript- correspondiente a la información demografica y datos agregados del consumo de agua en la Ciudad de México y sus delegaciones.

Todo el listado se integra en el sistema dentro de la variable **emision_referencia**.

Puede consultar el [esquema](/Docs/images/DER.png) y el [detalle-guía](/Docs/Gen_ER.md) del procesamiento.

La generación de este archivo se  incluye en el script R **CodigoDatos.R**      

<hr>



