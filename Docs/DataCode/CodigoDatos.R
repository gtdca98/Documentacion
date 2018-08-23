########################################################################################################################################################################
#### PROCESAMIENTO DE INFORMACIÓN
#### PREREQUISITOS: CENSO DE POBLACIÓN Y VIVIENDA 2010 (POSTGRESQL)
####                DESCARGA DE ARCHIVOS DEL CENSO DE POBLACION Y VIVIENDA 2010
####                             http://www.beta.inegi.org.mx/proyectos/ccpv/2010/default.html
####                DESCARGA DE ARCHIVOS GEOESPACIALES DE COLONIAS         (coloniasmexico.zip)
####                             http://datamx.io/dataset/colonias-mexico/resource/7b5a3b0a-4405-48d6-a4eb-d9f13bb50d3a
####                DESCARGA DE CATALOGO DE CODIGOS POSTALES (codigospostales.zip)
####                             http://www.sepomex.gob.mx/lservicios/servicios/CodigoPostal_Exportar.aspx
####                DESCARGA DE ARCHIVOS GEOESPACIALES DE CODIGOS POSTALES (codigospostales.zip)
####                             https://datos.gob.mx/busca/dataset/codigos-postales-coordenadas-y-colonias
####                DESCARGA DE ARCHIVOS GEOESPACIALES DE CARTOGRAFÌA GEOESTADÌSTICA URBANA Y RURAL AMANZANADA. O MAS RECIENTE (NOMBRE DIVERSO TAMAÑO 2.4GB)
####                             http://www.beta.inegi.org.mx/app/biblioteca/ficha.html?upc=889463526636
####                ARCHIVOS DE LA EMISIÓN DE BOLETAS DE SACMEX 
####                             Información proporcionada por el Sistema de Aguas de la Ciudad de México
####
########################################################################################################################################################################

library(rgdal)
library(dplyr)
library(tidyr)
library(stringr)
library(rmapshaper)
library(spdplyr)
library(geojsonio)
library(RPostgreSQL)

setwd("/Users/cad_salud/SACMEX/")


creadatajs<-function(origen, ruta ="", tbl=FALSE){
  nomfil<-deparse(substitute(origen))
  a_salida=paste0(ruta,nomfil,".js")
  linea= paste0("var ", nomfil ," = [ ")
  write(linea,file=a_salida,append = FALSE)
  for (i in 1:nrow(origen)){
    linea=paste0('[ "',origen[i,1])
    for (j in 2:ncol(origen)){
      linea= paste(linea, origen[i,j], sep = '", "' )
    }
    linea=ifelse(i < nrow(origen),paste0(linea,'" ],'),paste0(linea,'" ]'))
    #print(x = linea)
    write(linea,file=a_salida,append = TRUE)
  }
  write(" ];",file=a_salida,append = TRUE)
  ### crea comando para asociarlo a una tabla
  if (tbl==T){
    write("$(document).ready(function() {",file=a_salida,append = TRUE)
    write(paste0("   $('#tbl",nomfil,"').DataTable( {"),file=a_salida,append = TRUE)
    write(paste0("      data: ",nomfil," ,"),file=a_salida,append = TRUE)
    write("      columns: [",file=a_salida,append = TRUE)
    for (t in colnames(origen)){
      headerp<-ifelse(t==colnames(origen)[ncol(origen)], 
                      paste0( "          { title: ",'"',t ,'"', "}"),
                      paste0( "          { title: ",'"',t ,'"', "},")
      )
      write(headerp,file=a_salida,append = TRUE)
    }
    write("              ]",file=a_salida,append = TRUE)
    write("  } );",file=a_salida,append = TRUE)
    write("} );",file=a_salida,append = TRUE)
    
  }
}



### Quitar acentos

sinAccento <- function(text) {
  text <- gsub("['`^~\"]", " ", text)
  text <- iconv(text, to="ASCII//TRANSLIT//IGNORE")
  text <- gsub("\"u", "ü", text)  ## excepto ü
  text <- gsub("['`^\"]", "", text)
  text <- gsub("~n", "ñ", text) ## excepto  ñ
  text <- gsub("~N", "Ñ", text) ## excepto  Ñ
  return(text)
}

#################  Procesamiento emision SACMEX
###### SACMEX proporcionó la emisión de boletas por bimestre de 2016 por delegación 
######  este proceso integra toda la información en un solo data frame

crea_emisionanual<-function(){
  ###listado de archivos
  lista<-read.csv('DATOS/REPORTES PADRON USUARIOS/lista.csv',colClasses = c("character","character"))
  ### creacion del dataframe
  emisionSacmex=data.frame()
  for (x in 1:nrow(lista)){
    rutadatos= "DATOS/REPORTES PADRON USUARIOS/"
    print (paste0("Procesando archivo ",(x)," de ",nrow(lista)))
    qaz<-read.csv(paste0(rutadatos,lista[x,1]),stringsAsFactors = F,colClasses = 
                    c('integer','integer','character','character','character','character',
                      'character','character','character',
                      'integer','integer','integer','integer','numeric',
                      'integer','integer','integer','integer','character'))
    qaz$USO<-iconv(qaz$USO,from = "latin1",to = "UTF-8")
    qaz$cve_mun<-lista[x,2]
    if (x==1){
      emisionSacmex<-qaz
    }
    if (x>1){
      emisionSacmex<-rbind(emisionSacmex,qaz)
    }
  }
  saveRDS(emisionSacmex , "DATOS2/emisionSacmex.rds")
}

## procesamos la emision
crea_emisionanual()



## leemos la emision sacmex
emisionSacmex<-readRDS("DATOS2/emisionSacmex.rds")
## agrupamos por numero de cuenta, delegacion, CP y USO
## calificaos el cumplimiento por cuenta y los importes correspondientes
## Incumplimineto numero de botetas pagadas / total de boletas emitidas
## solamente se estan considerando consumos medidos


EmisionXCuenta<-emisionSacmex%>%filter(SISTEMAEMISION=="CONSUMO MEDIDO")%>%
  group_by(CUENTA,cve_mun,CP,USO)%>%
  summarise(frec=n(),
            pagos=sum(ifelse(PAGADO=="PAGADO",IMPORTE_TOTAL,0)),
            adeudos=sum(ifelse(PAGADO!="PAGADO",IMPORTE_TOTAL,0)),
            idxCumplimiento=round(sum(ifelse(PAGADO=="PAGADO",1,0))/n(),4),
            consumoPromedio= mean(CONSUMO_TOTAL),
            facturaPromedio= mean(IMPORTE_TOTAL))

saveRDS(EmisionXCuenta , "DATOS2/EmisionXCuenta.rds")

EmisionXCuenta<-readRDS( "DATOS2/EmisionXCuenta.rds")



############################################################################################################################
############################################################################################################################


#                        ██                  ██                                                       ▄▄▄▄                                                        ██                            ██              
#                        ▀▀                  ▀▀                                                      ██▀▀▀                                                        ▀▀                            ▀▀              
#  ▄████▄   ████▄██▄   ████     ▄▄█████▄   ████      ▄████▄   ██▄████▄           ██▄████   ▄████▄   ███████    ▄████▄    ██▄████   ▄████▄   ██▄████▄   ▄█████▄   ████      ▄█████▄             ████     ▄▄█████▄ 
# ██▄▄▄▄██  ██ ██ ██     ██     ██▄▄▄▄ ▀     ██     ██▀  ▀██  ██▀   ██           ██▀      ██▄▄▄▄██    ██      ██▄▄▄▄██   ██▀      ██▄▄▄▄██  ██▀   ██  ██▀    ▀     ██      ▀ ▄▄▄██               ██     ██▄▄▄▄ ▀ 
# ██▀▀▀▀▀▀  ██ ██ ██     ██      ▀▀▀▀██▄     ██     ██    ██  ██    ██           ██       ██▀▀▀▀▀▀    ██      ██▀▀▀▀▀▀   ██       ██▀▀▀▀▀▀  ██    ██  ██           ██     ▄██▀▀▀██               ██      ▀▀▀▀██▄ 
# ▀██▄▄▄▄█  ██ ██ ██  ▄▄▄██▄▄▄  █▄▄▄▄▄██  ▄▄▄██▄▄▄  ▀██▄▄██▀  ██    ██           ██       ▀██▄▄▄▄█    ██      ▀██▄▄▄▄█   ██       ▀██▄▄▄▄█  ██    ██  ▀██▄▄▄▄█  ▄▄▄██▄▄▄  ██▄▄▄███     ██        ██     █▄▄▄▄▄██ 
#   ▀▀▀▀▀   ▀▀ ▀▀ ▀▀  ▀▀▀▀▀▀▀▀   ▀▀▀▀▀▀   ▀▀▀▀▀▀▀▀    ▀▀▀▀    ▀▀    ▀▀           ▀▀         ▀▀▀▀▀     ▀▀        ▀▀▀▀▀    ▀▀         ▀▀▀▀▀   ▀▀    ▀▀    ▀▀▀▀▀   ▀▀▀▀▀▀▀▀   ▀▀▀▀ ▀▀     ▀▀        ██      ▀▀▀▀▀▀  
#                                                                                                                                                                                            ████▀              
#                                                                     ▀▀▀▀▀▀▀▀▀▀                                                  


### emisión por delegacion
EmisionXDEL<-EmisionXCuenta%>%
  group_by(USO,cve_mun)%>%
  summarise(DCTAS=n(),
            DPAGOS=sum(pagos),
            DDEUDA=sum(adeudos),
            DIDXCUM=mean(idxCumplimiento),
            DCONPRO= mean(consumoPromedio),
            DFACPRO= mean(facturaPromedio))%>%
  filter(USO=="DOMÉSTICO")%>%ungroup()%>%select(-USO)%>%
  full_join(
    (EmisionXCuenta%>%
       filter(USO=="MIXTO")%>%
       group_by(cve_mun)%>%
       summarise(MCTAS=n(),
                 MPAGOS=sum(pagos),
                 MDEUDA=sum(adeudos),
                 MIDXCUM=mean(idxCumplimiento),
                 MCONPRO= mean(consumoPromedio),
                 MFACPRO= mean(facturaPromedio))%>%
       ungroup()),
    by = c("cve_mun")
  )%>%
  full_join(
    (EmisionXCuenta%>%
       filter(USO=="NO DOMÉSTICO")%>%
       group_by(cve_mun)%>%
       summarise(NDCTAS=n(),
                 NDPAGOS=sum(pagos),
                 NDDEUDA=sum(adeudos),
                 NDIDXCUM=mean(idxCumplimiento),
                 NDCONPRO= mean(consumoPromedio),
                 NDFACPRO= mean(facturaPromedio))%>%
       ungroup()),
    by = c("cve_mun")
  )

saveRDS(EmisionXDEL , "DATOS2/EmisionXDEL.rds")

## integramos datos del Censo Nacional de poblacion y vivienda 2010
## se asume que ya esta cargado en postgresql 

## consultamos datos por delegacion: Poblacion total, Viviendas totales, viviendas con servicio de agua,
##  viviendas con lavadora, viviendas con servicio sanitario.


con <- dbConnect(PostgreSQL(), host="localhost", user= "postgres" , dbname="censo2010")
query= "select entidad as CVE_ENT, mun as CVE_MUN,  OCUPVIVPAR as pobtot, VIVPAR_HAB as vivtot, vph_aguadv,vph_lavad,vph_excsa from cpv2010 where entidad = '09' and mun != '000' and loc ='0000' and ageb= '0000' and mza ='000';"

data_del <- RPostgreSQL::dbGetQuery(con, query)%>%replace(is.na(.), 0)
colnames(data_del)<-toupper(colnames(data_del))

## integramos los datos DELEGACION de la emisión SACMEX con los del CENSO2010
deleg<-EmisionXDEL%>%left_join(data_del,by=c("cve_mun"="CVE_MUN"))
colnames(deleg)<-toupper(colnames(deleg))

saveRDS(deleg , "DATOS2/deleg.rds")

### datos del total del estado Ciudad de México
EmisionXCuenta$CVE_ENT='09'
EmisionXedo<-EmisionXCuenta%>%
  group_by(USO,CVE_ENT)%>%
  summarise(DCTAS=n(),
            DPAGOS=sum(pagos),
            DDEUDA=sum(adeudos),
            DIDXCUM=mean(idxCumplimiento),
            DCONPRO= mean(consumoPromedio),
            DFACPRO= mean(facturaPromedio))%>%
  filter(USO=="DOMÉSTICO")%>%ungroup()%>%select(-USO)%>%
  full_join(
    (EmisionXCuenta%>%
       filter(USO=="MIXTO")%>%
       group_by(CVE_ENT)%>%
       summarise(MCTAS=n(),
                 MPAGOS=sum(pagos),
                 MDEUDA=sum(adeudos),
                 MIDXCUM=mean(idxCumplimiento),
                 MCONPRO= mean(consumoPromedio),
                 MFACPRO= mean(facturaPromedio))%>%
       ungroup()),
    by = c("CVE_ENT")
  )%>%
  full_join(
    (EmisionXCuenta%>%
       filter(USO=="NO DOMÉSTICO")%>%
       group_by(CVE_ENT)%>%
       summarise(NDCTAS=n(),
                 NDPAGOS=sum(pagos),
                 NDDEUDA=sum(adeudos),
                 NDIDXCUM=mean(idxCumplimiento),
                 NDCONPRO= mean(consumoPromedio),
                 NDFACPRO= mean(facturaPromedio))%>%
       ungroup()),
    by = c("CVE_ENT")
  )

EmisionXedo$CVE_ENT='000'
colnames(EmisionXedo)[1]="cve_mun"

saveRDS(EmisionXedo , "DATOS2/EmisionXedo.rds")

con <- dbConnect(PostgreSQL(), host="localhost", user= "postgres" , dbname="censo2010")
query= "select entidad as CVE_ENT,'000' as CVE_MUN,  OCUPVIVPAR as pobtot, VIVPAR_HAB as vivtot, vph_aguadv,vph_lavad,vph_excsa from cpv2010 where entidad = '09' and mun = '000' and loc ='0000' and ageb= '0000' and mza ='000';"


data_ent <- RPostgreSQL::dbGetQuery(con, query)%>%replace(is.na(.), 0)
colnames(data_ent)<-toupper(colnames(data_ent))

enti<-EmisionXedo%>%left_join(data_ent,by=c("cve_mun"="CVE_MUN"))
colnames(enti)<-toupper(colnames(enti))

emision_referencia= rbind(deleg,enti)
saveRDS(emision_referencia , "DATOS2/emision_referencia.rds")

### genera archivo js de emision de referencia
creadatajs(emision_referencia,"DATOS2/",F)

############################################################################################################################
############################################################################################################################


# ▄▄▄▄▄                                   ▄▄▄▄▄▄                                  ▄▄    ▄▄   ▄▄▄▄▄      ▄▄▄▄    ▄▄           ██                                                          ██                                                ██               
# ██▀▀▀██               ██                ██▀▀▀▀██              ██                ██    ██  █▀▀▀▀██▄   ██▀▀██   ██           ▀▀                                                          ▀▀                                                ▀▀               
# ██    ██   ▄█████▄  ███████    ▄█████▄  ██    ██   ▄████▄   ███████    ▄████▄   ██    ██        ██  ██    ██  ██▄███▄    ████     ▄▄█████▄             ▄███▄██   ▄████▄    ▄████▄    ████     ▄▄█████▄   ▄████▄   ██▄████▄             ████     ▄▄█████▄  
# ██    ██   ▀ ▄▄▄██    ██       ▀ ▄▄▄██  ███████   ██▄▄▄▄██    ██      ██▀  ▀██  ████████      ▄█▀   ██    ██  ██▀  ▀██     ██     ██▄▄▄▄ ▀            ██▀  ▀██  ██▄▄▄▄██  ██▀  ▀██     ██     ██▄▄▄▄ ▀  ██▀  ▀██  ██▀   ██               ██     ██▄▄▄▄ ▀  
# ██    ██  ▄██▀▀▀██    ██      ▄██▀▀▀██  ██  ▀██▄  ██▀▀▀▀▀▀    ██      ██    ██  ██    ██    ▄█▀     ██    ██  ██    ██     ██      ▀▀▀▀██▄            ██    ██  ██▀▀▀▀▀▀  ██    ██     ██      ▀▀▀▀██▄  ██    ██  ██    ██               ██      ▀▀▀▀██▄  
# ██▄▄▄██   ██▄▄▄███    ██▄▄▄   ██▄▄▄███  ██    ██  ▀██▄▄▄▄█    ██▄▄▄   ▀██▄▄██▀  ██    ██  ▄██▄▄▄▄▄   ██▄▄██   ███▄▄██▀  ▄▄▄██▄▄▄  █▄▄▄▄▄██     ██     ▀██▄▄███  ▀██▄▄▄▄█  ▀██▄▄██▀     ██     █▄▄▄▄▄██  ▀██▄▄██▀  ██    ██     ██        ██     █▄▄▄▄▄██  
# ▀▀▀▀▀      ▀▀▀▀ ▀▀     ▀▀▀▀    ▀▀▀▀ ▀▀  ▀▀    ▀▀▀   ▀▀▀▀▀      ▀▀▀▀     ▀▀▀▀    ▀▀    ▀▀  ▀▀▀▀▀▀▀▀    ▀▀▀▀    ▀▀ ▀▀▀    ▀▀▀▀▀▀▀▀   ▀▀▀▀▀▀      ▀▀      ▄▀▀▀ ██    ▀▀▀▀▀     ▀▀▀▀       ██      ▀▀▀▀▀▀     ▀▀▀▀    ▀▀    ▀▀     ▀▀        ██      ▀▀▀▀▀▀   
#                                                                                                                                                       ▀████▀▀                      ████▀                                              ████▀              

### emision por codigo postal
EmisionXCP<-EmisionXCuenta%>%
  group_by(USO,cve_mun,CP)%>%
  summarise(DCTAS=n(),
            DPAGOS=sum(pagos),
            DDEUDA=sum(adeudos),
            DIDXCUM=mean(idxCumplimiento),
            DCONPRO= mean(consumoPromedio),
            DFACPRO= mean(facturaPromedio))%>%
  filter(USO=="DOMÉSTICO")%>%ungroup()%>%select(-USO)%>%
  full_join(
    (EmisionXCuenta%>%
       filter(USO=="MIXTO")%>%
       group_by(cve_mun,CP)%>%
       summarise(MCTAS=n(),
                 MPAGOS=sum(pagos),
                 MDEUDA=sum(adeudos),
                 MIDXCUM=mean(idxCumplimiento),
                 MCONPRO= mean(consumoPromedio),
                 MFACPRO= mean(facturaPromedio))%>%
       ungroup()),
    by = c("cve_mun","CP")
  )%>%
  full_join(
    (EmisionXCuenta%>%
       filter(USO=="NO DOMÉSTICO")%>%
       group_by(cve_mun,CP)%>%
       summarise(NDCTAS=n(),
                 NDPAGOS=sum(pagos),
                 NDDEUDA=sum(adeudos),
                 NDIDXCUM=mean(idxCumplimiento),
                 NDCONPRO= mean(consumoPromedio),
                 NDFACPRO= mean(facturaPromedio))%>%
       ungroup()),
    by = c("cve_mun","CP")
  )

saveRDS(EmisionXCP , "DATOS2/EmisionXCP.rds")

### la EmisionXCP tiene 1144 codigos postales distintos
length(unique(EmisionXCP$CP))


## leemos el geoObjeto  de codigos postales de la ciudad de mexico
shp09cp <- readOGR("/Users/cad_salud/SACMEX/DATOS/CP_CdMx/", 'CP_09CDMX_v4')
## tenemos 1225 poligonos de codigos postales
listaCP2c<-as.character(shp09cp@data$d_cp)
sum(EmisionXCP$CP%in%listaCP2c) ### 1067 localidados

## leemos el geoObjeto  de colonias general
shp09C <- readOGR("/Users/cad_salud/SACMEX/DATOS/Colonias/", 'Colonias')
### filtramos para obtener unicamente cdmx
shp09C <- shp09C[shp09C$ST_NAME =='DISTRITO FEDERAL',]
### 2097 poligonos de colonias en CDMX

listaCP2a<-shp09C@data$POSTALCODE
sum(EmisionXCP$CP%in%listaCP2a)  ### 1013 localidados
cpsfaltantes <-EmisionXCP[!(EmisionXCP$CP%in%listaCP2a),]$CP

sum(cpsfaltantes%in%listaCP2c) ### 82 localidados de los faltantes
length(unique(listaCP2a)) ### 1142

## aseguramos que la proyeccion de las colonias sea wgs84
shp09 <- spTransform(shp09C, CRS("+proj=longlat +datum=WGS84"))
## agregamos un identificador de renglon consecutivo
shp09@data$RECNOID= c(1:nrow(shp09@data))
### quitamos acentos
shp09@data$MUN_NAME=sinAccento(shp09@data$MUN_NAME)
shp09@data$SETT_NAME=sinAccento(shp09@data$SETT_NAME)
shp09@data$SETT_TYPE=sinAccento(shp09@data$SETT_TYPE)
#eliminamos campos que no usaremos 
shp09@data$AREA=NULL
shp09@data$Shape_Leng=NULL
shp09@data$Shape_Area=NULL
## ajsutamos el nombre del estado a CIUDAD DE MEXICO
shp09@data$ST_NAME = 'CIUDAD DE MEXICO'
## asignamos campos de claves y abreviatura de la delegacion
MUN_NAME =c("ALVARO OBREGON","AZCAPOTZALCO","BENITO JUAREZ","COYOACAN","CUAJIMALPA DE MORELOS","CUAUHTEMOC","GUSTAVO A MADERO","IZTACALCO","IZTAPALAPA","LA MAGDALENA CONTRERAS","MIGUEL HIDALGO","MILPA ALTA","TLAHUAC","TLALPAN","VENUSTIANO CARRANZA","XOCHIMILCO" )           
ABREV =c("A.OBREGON","AZCAPOTZALCO","B.JUAREZ","COYOACAN","CUAJIMALPA","CUAUHTEMOC","G.A.MADERO","IZTACALCO","IZTAPALAPA","M.CONTRERAS","M.HIDALGO","M.ALTA","TLAHUAC","TLALPAN","V.CARRANZA","XOCHIMILCO")
CVE_MUN=c("010","002","014","003","004","015","005","006","007","008","016","009","011","012","017","013");
tblextra<-data.frame(cbind(MUN_NAME,ABREV,CVE_MUN),stringsAsFactors = F)
shp09@data=shp09@data%>%left_join(tblextra)
## todo a utf8
shp09@data$POSTALCODE=iconv(shp09@data$POSTALCODE,from = 'latin1', to = "UTF-8")
shp09@data$ST_NAME=iconv(shp09@data$ST_NAME,from = 'latin1', to = "UTF-8")
shp09@data$MUN_NAME=iconv(shp09@data$MUN_NAME,from = 'latin1', to = "UTF-8")
shp09@data$SETT_NAME=iconv(shp09@data$SETT_NAME,from = 'latin1', to = "UTF-8")
shp09@data$SETT_TYPE=iconv(shp09@data$SETT_TYPE,from = 'latin1', to = "UTF-8")
shp09@data$ABREV=iconv(shp09@data$ABREV,from = 'latin1', to = "UTF-8")
shp09@data$CVE_MUN=iconv(shp09@data$CVE_MUN,from = 'latin1', to = "UTF-8")
## guardamos shp de colonias porque vamos a cruzarlo con el de manzanas para obtener información agrupada por colonia
writeOGR(shp09, "DATOS2/", "ColoniasCDMX", driver="ESRI Shapefile",overwrite_layer = TRUE)

#####################
##leemos las colonias recien ajustadas
shp09_COL09 <- readOGR("DATOS2/", 'ColoniasCDMX')

lstcp<-shp09_COL09@data%>%group_by(POSTALCODE)%>%summarise(n=n())%>%ungroup()%>%filter(n>1)

##leemos el catalogo de códigos postales
cp09<-read.csv2('DATOS/CP_CdMx/CPdescarga20180220.txt',skip = 1,sep = '|',header = T,stringsAsFactors=FALSE, fileEncoding="latin1", colClasses = rep("character",15)) %>%
  filter(c_estado=='09')
##listado de CP multiples 
multiCP<-cp09%>%group_by(d_codigo)%>%summarise(n=n())%>%ungroup()%>%filter(n>1)
### verificamos cuantos poligomos de colonias tenemos identificados en multiCP
sum(lstcp$POSTALCODE %in% unique(multiCP$d_codigo))  ## 217 CP's de colonias multiples se ubican de los 272 actuales casos
sum(lstcp$n) ## 1365 casos en multiplicidad en colonias
###reducimos la multiplicidad a los casos que tenemos con SHP 
multiCP=multiCP[multiCP$d_codigo %in% lstcp$POSTALCODE,]  ## 217 casos con 638 asentamientos

## separamos el layer en un shp especial que mas adelante se añadirá al shape de CP's que corresponden a una colonia
shp09_COL09_multi<-shp09_COL09[shp09_COL09$POSTALCODE %in% lstcp$POSTALCODE, ]
shp09_COL09_multi@data=shp09_COL09_multi@data%>%rename( D_CP = POSTALCODE,D_ASENTA=SETT_NAME ,D_TIPO=SETT_TYPE)
#integramos campo llave de busqueda
shp09_COL09_multi@data$D_ASENTA2 =  paste0(shp09_COL09_multi@data$D_ASENTA , " (-" ,shp09_COL09_multi@data$D_TIPO, "-) ")

##quitamos columnas 
shp09_COL09_multi@data$ST_NAME=NULL
shp09_COL09_multi@data$MUN_NAME=NULL
shp09_COL09_multi@data$RECNOID=NULL
shp09_COL09_multi@data$ABREV=NULL
shp09_COL09_multi@data$OBJECTID=NULL

writeOGR(shp09_COL09_multi, "DATOS2/", "ColoniasCDMXmulti", driver="ESRI Shapefile",overwrite_layer = TRUE)

###leemos el shp de codigos postales más reciente
shp09_cp <- readOGR("/Users/cad_salud/SACMEX/DATOS/CP_CdMx/", 'CP_09CDMX_v4')
## aseguramos que la proyeccion sea wgs84
shp09cp <- spTransform(shp09_cp, CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"))
writeOGR(shp09cp, "DATOS2/", "CP_09wgs84", driver="ESRI Shapefile",overwrite_layer = TRUE)

### verificamos cuantos poligomos de colonias tenemos identificados en multiCP
sum(shp09cp@data$d_cp %in%multiCP$d_codigo)  ## 213 casos
sum(multiCP$n) ## 638 casos en multiplicidad
#### contabilizamos en terminos de CP's distintos
sum(unique(shp09cp@data$d_cp) %in%multiCP$d_codigo) ## 213 de 272 originales
## (4 CP's no esta localizados pero si se mostraran poruqe ya existen en colonias)

## separamos el layer en un shp especial que mas adelante se añadirá al shape de CP's que corresponden a una colonia
shp09cp_simple<-shp09cp[!(shp09cp$d_cp %in% multiCP$d_codigo), ]

##Preparamos  información este layer simple no tiene datos

### DATOS DE CP's que NO comparten código postal 
cp09_b<-cp09[!(cp09$d_codigo %in% multiCP$d_codigo),]%>%
  select(d_codigo,d_asenta,d_tipo_asenta,c_mnpio)%>%arrange(d_codigo)%>%
  right_join(cp09%>%group_by(d_codigo)%>%summarise(n=n())%>%ungroup())%>%
  mutate(D_ASENTA=toupper(sinAccento(d_asenta)),D_TIPO= toupper(sinAccento(d_tipo_asenta)),D_CP=d_codigo, CVE_MUN=c_mnpio)%>%
  mutate(D_ASENTA2 = paste0(D_ASENTA , " (" ,D_TIPO, ") "))%>%filter(!is.na(D_ASENTA))
## vectorizamos el nombre del asentamiento para que se reduzca a un solo renglon
## para estos casos no existen shapes separados pero el poligono apuntará al una 
## posicion aproximada

cp09_b2<-unique(cp09_b[,c('D_CP','CVE_MUN')])

### funcion que integra multi asentamientos 
geMultiAsentamientos=function(cpost){
  selected=cp09_b%>%filter(D_CP==cpost)%>%select(D_CP, D_ASENTA2)%>%spread(key = D_ASENTA2,value = D_ASENTA2)
  columnas<-names(selected%>%select(-D_CP))
  salida=selected%>%unite(col='D_ASENTA2',columnas,sep= "|| ")
  return(salida) ### la salida es un df de 1 renglón
}

library(purrr)  ### para poder usar funciones map
cp09_c<-unique(cp09_b$d_codigo)%>% 
  map_dfr(.,geMultiAsentamientos) %>% ### integra las salidas por rbind
  left_join(cp09_b2)

cp09_c$D_ASENTA =cp09_c$D_ASENTA2 
cp09_c$D_TIPO ="-"

shp09cp_simple@data=shp09cp_simple@data%>%
  left_join(cp09_c%>%
              select(D_CP,D_ASENTA,D_TIPO,CVE_MUN ,D_ASENTA2),by = c("d_cp"="D_CP"))
## ajustamos el nombre del campo CP
shp09cp_simple@data=shp09cp_simple@data%>%rename(D_CP=d_cp)
writeOGR(shp09cp_simple, "DATOS2/", "ColoniasCDMXsimple", driver="ESRI Shapefile",overwrite_layer = TRUE)

##Veamos la union del multi y el simple aunque se traslapen en algunos casos

shp09cp_unido = rbind.SpatialPolygonsDataFrame(shp09cp_simple,shp09_COL09_multi,makeUniqueIDs = T)
shp09cp_simple@proj4string
shp09_COL09_multi@proj4string

writeOGR(shp09cp_unido, "DATOS2/", "ColoniasCDMXunido", driver="ESRI Shapefile",overwrite_layer = TRUE)

#### leemos el archivo recien construido que ya contiene 2377 policgonos
shp09cp_unido <- readOGR("DATOS2/", 'ColoniasCDMXunido')

##############


### asignacion de codigos postales a los datos del censo de poblacion
### se toman el shp de manzanas y se calculan los centriodes mismos que se cruzan con los poligonos de codigos postales
### decimos que una manzana corresponde a un codigo postal si su centroide se localiza dentro del área que forma el codigo postal
### con ello podemos saber cual es la población, viviendas, viviendas con regadera, wc, servicio de agua por CP
### y aplicar proporciones mas adecuadas a la experiencia de usuario en la calculadora de consumo responsable de agua

### abrimos el shp de manzanas en cdmx
shp09_m <- readOGR("/Users/cad_salud/SACMEX/DATOS/AGEBS_CDMX/conjunto de datos/", '09m')
### aseguramos que la proyeccion sea wgs84
shp09_mza <- spTransform(shp09_m, CRS("+proj=longlat +datum=WGS84"))
## eliminamos el campo que no usamos
shp09_mza@data$TIPOMZA<- NULL
### almacenamos la variable de proyeccion que mas adelante asignaremos al layer de centroides
proj4strmzaBASE<-shp09_mza@proj4string
### calculamos los centroides de los poligonos de las manzanas
centroids <- getSpPPolygonsLabptSlots(shp09_mza)
centroids2<-as.data.frame(centroids)
colnames(centroids2)<- c("x","y")
##añadimos los centroides al data del shape de manzanas
pointsMZA<-cbind(centroids2,shp09_mza@data)
### asignamos la proyeccion a los centroides 
puntos<-SpatialPoints(centroids2, proj4string=proj4strmzaBASE)
### construimos el layer de puntos
centroidMZAlayer<-SpatialPointsDataFrame(coords = puntos,data = pointsMZA,proj4string = proj4strmzaBASE)
## guardamos para realizar el cruce en QGIS vs Codigos postales
writeOGR(obj = centroidMZAlayer, dsn = 'DATOS2/', layer = '09m_centroids', driver="ESRI Shapefile",overwrite_layer = TRUE)


####

####codigo python 
### Añadiremos los atributos del polígono a cada punto del centroide
# import processing
# ## PROCESO INTERSECCION SEGUNDA PARTE
# layer1 = "/Users/cad_salud/SACMEX/DATOS/CP_CdMx/CP_09CDMX_v4.shp"
# layer2 =  "/Users/cad_salud/SACMEX/DATOS/AGEBS_CDMX/conjunto de datos/09m_centroids.shp"
# campos = ["OBJECTID" ,"POSTALCODE" ,"ST_NAME" ,"MUN_NAME" ,"SETT_NAME","SETT_TYPE", "RECNOID", "ABREV","CVE_MUN"]
# layer3 = "/Users/cad_salud/SACMEX/DATOS2//09m_centroidsCP.shp"
# processing.runalg('saga:addpolygonattributestopoints', layer2, layer1, campos ,layer3)
# layer = QgsVectorLayer(layer1, "caminos", "ogr")
# layer.commitChanges() 
# # 
# print "FIN DE PROCESO"####
# 
# 

### leemos el shp generado  

shp09_mc <- readOGR("/Users/cad_salud/SACMEX/DATOS/AGEBS_CDMX/conjunto de datos/", '09m_centroidsCP')
## eliminamos los registros incompletos (31 casos)
shp09_mc@data<-shp09_mc@data[!is.na(shp09_mc@data$d_cp),]
### añadimos la información del censo a nivel de manzana
### leemos datos del censo 2010
con <- dbConnect(PostgreSQL(), host="localhost", user= "postgres" , dbname="censo2010")
query= "select entidad as CVE_ENT, mun as CVE_MUN, loc as cve_loc, ageb as cve_ageb, mza as cve_mza, pobtot, vivtot, vph_aguadv,vph_lavad,vph_excsa from cpv2010 where entidad = '09' and mun != '000' and loc !='0000' and ageb!= '0000' and mza !='000';"

query= "select entidad as CVE_ENT, mun as CVE_MUN, loc as cve_loc, ageb as cve_ageb, mza as cve_mza, OCUPVIVPAR as pobtot, VIVPAR_HAB as vivtot, vph_aguadv,vph_lavad,vph_excsa from cpv2010 where entidad = '09' and mun != '000' and loc !='0000' and ageb!= '0000' and mza ='000';"

data_mza <- RPostgreSQL::dbGetQuery(con, query)%>%replace(is.na(.), 0)
colnames(data_mza)<-toupper(colnames(data_mza))
saveRDS(data_mza,"DATOS2/data_mza.rds")

###integramos los datos en el shp  de manzana
shp09_mc@data=shp09_mc@data%>%inner_join(data_mza%>%select(-CVE_MZA))
### agrupamos los datos por CP
data_mc=shp09_mc@data%>%
  group_by(d_cp,CVE_MUN)%>%
  summarise(POBTOT=mean(POBTOT) ,
            VIVTOT=mean(VIVTOT),
            VPH_AGUADV=mean(VPH_AGUADV),
            VPH_LAVAD=mean(VPH_LAVAD),
            VPH_EXCSA=mean(VPH_EXCSA))%>%
  ungroup()%>%
  left_join(EmisionXCP,
            by = c("d_cp"="CP")
  )%>%
  filter(is.na(POBTOT)==F | POBTOT<1 |  VIVTOT<1)
summary(data_mc)

## todos los CP en este dataframe estan en el SHP unido 
## 0 = nada falta
sum(!(data_mc$d_cp %in% shp09cp_unido@data$D_CP))

## generamos el SHP ampliado que se usa en la aplicacion
data_mc2<-data.frame(data_mc)
shp09final <- readOGR("DATOS2/", "ColoniasCDMXunido")
shp09final@data= shp09final@data%>%left_join(data_mc2, by = c("D_CP"= "d_cp","CVE_MUN","CVE_MUN") )
##quitamos campos
shp09final@data$cve_mun=NULL
## añadimos descriptores de delegaciones
MUN_NAME =c("ALVARO OBREGON","AZCAPOTZALCO","BENITO JUAREZ","COYOACAN","CUAJIMALPA DE MORELOS","CUAUHTEMOC","GUSTAVO A MADERO","IZTACALCO","IZTAPALAPA","LA MAGDALENA CONTRERAS","MIGUEL HIDALGO","MILPA ALTA","TLAHUAC","TLALPAN","VENUSTIANO CARRANZA","XOCHIMILCO" )           
ABREV =c("A.OBREGON","AZCAPOTZALCO","B.JUAREZ","COYOACAN","CUAJIMALPA","CUAUHTEMOC","G.A.MADERO","IZTACALCO","IZTAPALAPA","M.CONTRERAS","M.HIDALGO","M.ALTA","TLAHUAC","TLALPAN","V.CARRANZA","XOCHIMILCO")
CVE_MUN=c("010","002","014","003","004","015","005","006","007","008","016","009","011","012","017","013");
tblextra<-data.frame(cbind(MUN_NAME,ABREV,CVE_MUN),stringsAsFactors = F)
shp09final@data= shp09final@data%>%left_join(tblextra, by = c("CVE_MUN","CVE_MUN") )

writeOGR(obj = shp09final, dsn = 'DATOS2/', layer = '09retoh2obis', driver="ESRI Shapefile",overwrite_layer = TRUE)
shp09final

#### la conversion a geojson se realiza en QGIS usando guardarcomo /exportar a geojson con nombre DataRetoH2Obis.geojson
#### después se renombra añadiendo la extensión js 
#### se edita el archivo y se le añade al inicio var colCDMX = [ y al final se le agrega el cierre de corchete ];

############################################################################################################################
############################################################################################################################


#                     ▄▄▄▄                   ▄▄▄▄   ▄▄▄▄▄▄                 ██              
#                     ▀▀██                 ██▀▀▀▀█  ██▀▀▀▀█▄               ▀▀              
#  ▄█████▄   ▄████▄     ██                ██▀       ██    ██             ████     ▄▄█████▄ 
# ██▀    ▀  ██▀  ▀██    ██                ██        ██████▀                ██     ██▄▄▄▄ ▀ 
# ██        ██    ██    ██                ██▄       ██                     ██      ▀▀▀▀██▄ 
# ▀██▄▄▄▄█  ▀██▄▄██▀    ██▄▄▄              ██▄▄▄▄█  ██           ██        ██     █▄▄▄▄▄██ 
#   ▀▀▀▀▀     ▀▀▀▀       ▀▀▀▀                ▀▀▀▀   ▀▀           ▀▀        ██      ▀▀▀▀▀▀  
#                                                                     ████▀              
#                              ▀▀▀▀▀▀▀▀▀▀                                                  



### listado desplegable

cp09_colcp<-shp09final@data%>%
  select(D_CP,MUN_NAME,D_ASENTA2)%>%filter(is.na(MUN_NAME) == F & is.na(D_ASENTA2)==F)%>%
  mutate(lista= paste0("['",D_CP,"','",MUN_NAME,"','",D_ASENTA2,"'],"))

## verificamos todo bien si repetidos 
cp09_colcp %>% group_by(D_ASENTA2,D_CP) %>% summarise(n=n()) %>% filter (n>1)


## deben eliminarse las comillas dobles
col_CP<-cp09_colcp[,c('D_CP','MUN_NAME','D_ASENTA2')]
creadatajs(col_CP,"DATOS2/",F)

## se edita y al inicio se cambia : col_CP por  listacol 


############################################################################################################################
############################################################################################################################


#    ▄▄▄▄   ▄▄▄▄▄     ▄▄▄  ▄▄▄  ▄▄▄  ▄▄▄               ██              
#  ██▀▀▀▀█  ██▀▀▀██   ███  ███   ██▄▄██                ▀▀              
# ██▀       ██    ██  ████████    ████               ████     ▄▄█████▄ 
# ██        ██    ██  ██ ██ ██     ██                  ██     ██▄▄▄▄ ▀ 
# ██▄       ██    ██  ██ ▀▀ ██    ████                 ██      ▀▀▀▀██▄ 
#  ██▄▄▄▄█  ██▄▄▄██   ██    ██   ██  ██      ██        ██     █▄▄▄▄▄██ 
#    ▀▀▀▀   ▀▀▀▀▀     ▀▀    ▀▀  ▀▀▀  ▀▀▀     ▀▀        ██      ▀▀▀▀▀▀  
#                                                 ████▀              


#### generacion del shape CDMX en geojson
ruta = "DATOS/AGEBS_CDMX/conjunto de datos"
ogrfile2 = "areas_geoestadisticas_estatales"
shapeoriginal <- readOGR(ruta, ogrfile2)
shapeCDMX <-shapeoriginal[shapeoriginal$CVE_ENT=="09",]
map_wgs84CDMX <- spTransform(shapeCDMX, CRS("+proj=longlat +datum=WGS84"))
map_wgs84CDMX@data$NOM_ENT<-iconv(map_wgs84CDMX@data$CVE_ENT,from ="latin1",to="utf8", "")
json_ent<-geojson_json(map_wgs84CDMX)
geojson_write(json_ent, file = "DATOS2/CDMX.js")

#### se edita el archivo y se le añade al inicio var CDMX = [ y al final se le agrega el cierre de corchete ];


############################################################################################################################
############################################################################################################################

#                                  ▄▄▄▄   ▄▄▄▄▄     ▄▄▄  ▄▄▄  ▄▄▄  ▄▄▄                                             ██                                                ██              
#                                ██▀▀▀▀█  ██▀▀▀██   ███  ███   ██▄▄██                                              ▀▀                                                ▀▀              
# ████▄██▄  ██    ██  ██▄████▄  ██▀       ██    ██  ████████    ████               ▄███▄██   ▄████▄    ▄████▄    ████     ▄▄█████▄   ▄████▄   ██▄████▄             ████     ▄▄█████▄ 
# ██ ██ ██  ██    ██  ██▀   ██  ██        ██    ██  ██ ██ ██     ██               ██▀  ▀██  ██▄▄▄▄██  ██▀  ▀██     ██     ██▄▄▄▄ ▀  ██▀  ▀██  ██▀   ██               ██     ██▄▄▄▄ ▀ 
# ██ ██ ██  ██    ██  ██    ██  ██▄       ██    ██  ██ ▀▀ ██    ████              ██    ██  ██▀▀▀▀▀▀  ██    ██     ██      ▀▀▀▀██▄  ██    ██  ██    ██               ██      ▀▀▀▀██▄ 
# ██ ██ ██  ██▄▄▄███  ██    ██   ██▄▄▄▄█  ██▄▄▄██   ██    ██   ██  ██      ██     ▀██▄▄███  ▀██▄▄▄▄█  ▀██▄▄██▀     ██     █▄▄▄▄▄██  ▀██▄▄██▀  ██    ██     ██        ██     █▄▄▄▄▄██ 
# ▀▀ ▀▀ ▀▀   ▀▀▀▀ ▀▀  ▀▀    ▀▀     ▀▀▀▀   ▀▀▀▀▀     ▀▀    ▀▀  ▀▀▀  ▀▀▀     ▀▀      ▄▀▀▀ ██    ▀▀▀▀▀     ▀▀▀▀       ██      ▀▀▀▀▀▀     ▀▀▀▀    ▀▀    ▀▀     ▀▀        ██      ▀▀▀▀▀▀  
#                                                                                  ▀████▀▀                      ████▀                                             ████▀              






#### generacion del shape mpoCDMX en geojson
con <- dbConnect(PostgreSQL(), host="localhost", user= "postgres" , dbname="censo2010")
query= "select entidad as cve_ent, mun as cve_mun, sum(pobtot) as pobtot, sum(vivtot) as vivtot, sum(vph_aguadv ) as vph_aguadv from CDMX group by entidad, mun;"
resumenMunicipal <- RPostgreSQL::dbGetQuery(con, query)
ogrfileMPOS = "E09areas_geoestadisticas_municipales"
shapempoCDMX <- readOGR(ruta, ogrfileMPOS)
map_wgs84mpoCDMX <- spTransform(shapempoCDMX, CRS("+proj=longlat +datum=WGS84"))
map_wgs84mpoCDMX@data$AREA<-NULL
map_wgs84mpoCDMX@data<-map_wgs84mpoCDMX@data%>%left_join(resumenMunicipal,by=c("CVE_ENT"="cve_ent","CVE_MUN"="cve_mun"))
writeOGR(obj = map_wgs84mpoCDMX, dsn = 'DATOS2/', layer = '09MPOampl', driver="ESRI Shapefile",overwrite_layer = TRUE)
json_ent<-geojson_json(map_wgs84mpoCDMX)
geojson_write(json_ent, file = "DATOS2/munCDMX.geojson")

#### se edita el archivo y se le añade al inicio var munCDMX = [ y al final se le agrega el cierre de corchete ];


############################################################################################################################
############################################################################################################################



