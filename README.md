# LADM-COL Reports

Repositorio que tiene los reportes diseñados para trabajar con los modelos basados en el modelo LADM-COL.
Actualmente se encuentran implementado dos reportes para el modelo de levantamiento de levantamiento catastral 1.0.

- **Anexo 17**: Es un reporte basado en la información y esquema del anexo #17 del documento “Conceptualización y especificaciones para la operación del Catastro Multipropósito” generado por el Instituto Geográfico Agustín Codazzi, IGAC.
- **Plano ANT**: Plano definido por la Agencia Nacional de Tierras, ANT que se utiliza para mostrar la información producto de la definición de cabida y linderos de los predios objeto del levantamiento catastral.

## Notas

- Trabajo realizado en su mayor parte por @mejiafabiandj y adoptado por @seralra96 y @lacardonap.
- Adaptado para ser utilizado por otras aplicaciones como:
  - [Asistente LADM-COL](https://github.com/SwissTierrasColombia/Asistente-LADM-COL) por @gacarrillor.
  - [Geoportal](https://github.com/SwissTierrasColombia/print_server) por @felipecanol.

## Para desarrollores

Los reportes son construidos utilizando la librería [mapfish-print](https://github.com/mapfish/mapfish-print).
Si se actualiza la versión de mapfish-print no se debe olvidar modificar la librería para dar soporte a la proyección Origen Nacional EPSG:9377.

```shell
wget https://github.com/mapfish/mapfish-print/releases/download/release%2F3.28.2/print-cli-3.28.2.zip
unzip print-cli-3.28.2.zip
mkdir tmp_lib
cd tmp_lib/
cp ../core-3.28.2/lib/print-lib-3.28.2.jar .
jar xvf print-lib-3.28.2.jar
rm print-lib-3.28.2.jar
# Se debe modificar el archivo `epsg.properties` para dar soporte a la proyección Origen Nacional
echo '9377=PROJCS["MAGNA-SIRGAS / CTM12",GEOGCS["MAGNA-SIRGAS",DATUM["Marco Geocentrico Nacional de Referencia",SPHEROID["GRS_1980",6378137.0,298.257222101]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Transverse_Mercator"],PARAMETER["False_Easting",5000000.0],PARAMETER["False_Northing",2000000.0],PARAMETER["Central_Meridian",-73.0],PARAMETER["Scale_Factor",0.9992],PARAMETER["Latitude_Of_Origin",4.0],UNIT["Meter",1.0]]' >> epsg.properties
jar -Mcvf print-lib-3.28.2.jar *
mv print-lib-3.28.2.jar ../core-3.28.2/lib/
cd ..
rm -rf tmp_lib/
```

Para algunos reportes se genera un código de barras.
Se deben incluir las siguientes librerías:
- barcode4j-2.1.jar
- core-3.2.1.jar
