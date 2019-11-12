WITH terrenos_seleccionados AS
  (SELECT 1522 AS ue_terreno --$P{id}
   WHERE '764' <> 'NULL' --12425  12424 12005
   UNION SELECT col_uebaunit.ue_op_terreno
   FROM ladmcol_2_9_6.op_predio --$P!{datasetName}
   LEFT JOIN ladmcol_2_9_6.col_uebaunit ON op_predio.t_id = col_uebaunit.baunit  --$P!{datasetName}
   WHERE col_uebaunit.ue_op_terreno IS NOT NULL
     AND CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE op_predio.matricula_inmobiliaria = 'NULL'
         END
   UNION SELECT col_uebaunit.ue_op_terreno
   FROM ladmcol_2_9_6.op_predio  --$P!{datasetName}
   LEFT JOIN ladmcol_2_9_6.col_uebaunit ON op_predio.t_id = col_uebaunit.baunit  --$P!{datasetName}
   WHERE col_uebaunit.ue_op_terreno IS NOT NULL
     AND CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE op_predio.numero_predial = 'NULL'
         END
   UNION SELECT col_uebaunit.ue_op_terreno
   FROM ladmcol_2_9_6.op_predio  --$P!{datasetName}
   LEFT JOIN ladmcol_2_9_6.col_uebaunit ON op_predio.t_id = col_uebaunit.baunit  --$P!{datasetName}
   WHERE col_uebaunit.ue_op_terreno IS NOT NULL
     AND CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE op_predio.numero_predial_anterior = 'NULL'
         END ),
     predios_seleccionados AS
  (SELECT col_uebaunit.baunit AS t_id
   FROM ladmcol_2_9_6.col_uebaunit --$P!{datasetName} 
   WHERE col_uebaunit.ue_op_terreno = 1522--$P{id}
     AND '764' <> 'NULL'
   UNION SELECT t_id
   FROM ladmcol_2_9_6.op_predio --$P!{datasetName}
   WHERE CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE op_predio.matricula_inmobiliaria = 'NULL'
         END
   UNION SELECT t_id
   FROM ladmcol_2_9_6.op_predio --$P!{datasetName}
   WHERE CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE op_predio.numero_predial = 'NULL'
         END
   UNION SELECT t_id
   FROM ladmcol_2_9_6.op_predio --$P!{datasetName}
   WHERE CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE op_predio.numero_predial_anterior = 'NULL'
         END ),
     derechos_seleccionados AS
  (SELECT DISTINCT op_derecho.t_id
   FROM ladmcol_2_9_6.op_derecho --$P!{datasetName}
   WHERE op_derecho.unidad IN
       (SELECT *
        FROM predios_seleccionados) ),
     derecho_interesados AS
  (SELECT DISTINCT op_derecho.interesado_op_interesado,
                   op_derecho.t_id
   FROM ladmcol_2_9_6.op_derecho --$P!{datasetName}
   WHERE op_derecho.t_id IN
       (SELECT *
        FROM derechos_seleccionados)
     AND op_derecho.interesado_op_interesado IS NOT NULL ),
     derecho_agrupacion_interesados AS
  (SELECT DISTINCT op_derecho.interesado_op_agrupacion_interesados,
                   col_miembros.interesado_op_interesado
   FROM ladmcol_2_9_6.op_derecho --$P!{datasetName}
   LEFT JOIN ladmcol_2_9_6.col_miembros ON op_derecho.interesado_op_agrupacion_interesados = col_miembros.agrupacion
   WHERE op_derecho.t_id IN
       (SELECT *
        FROM derechos_seleccionados)
     AND op_derecho.interesado_op_agrupacion_interesados IS NOT NULL ),
     info_terreno AS
  (SELECT op_terreno.area_terreno,
          st_x(st_transform(st_centroid(op_terreno.geometria), 4326)) AS x ,
          st_y(st_transform(st_centroid(geometria), 4326)) AS y
   FROM ladmcol_2_9_6.op_terreno --$P!{datasetName}
   WHERE op_terreno.t_id IN
       (SELECT *
        FROM terrenos_seleccionados) ),
     info_predio AS
  (SELECT op_predio.matricula_inmobiliaria AS fmi ,
          op_predio.nupre AS nupre ,
          op_predio.numero_predial AS numero_predial ,
          op_predio.nombre AS nombre ,
          op_predio.local_id ,
          op_predio.departamento ,
          op_predio.municipio ,
          --op_predio.zona ,
          op_predio.numero_predial_anterior ,
          op_predio.espacio_de_nombres || op_predio.local_id AS codigo
   FROM ladmcol_2_9_6.op_predio --$P!{datasetName}
   WHERE op_predio.t_id IN
       (SELECT *
        FROM predios_seleccionados) ),
     info_interesado AS
  (SELECT op_interesado.local_id AS local_id ,
          (CASE
               WHEN op_interesado.t_id IS NOT NULL THEN 'interesado'
           END) AS agrupacion_interesado ,
          (coalesce(op_interesado.primer_nombre, '') || coalesce(' ' || op_interesado.segundo_nombre, '') || coalesce(' ' || op_interesado.primer_apellido, '') || coalesce(' ' || op_interesado.segundo_apellido, '') || coalesce(op_interesado.razon_social, '')) AS nombre
   FROM derecho_interesados
   LEFT JOIN ladmcol_2_9_6.op_interesado ON op_interesado.t_id = derecho_interesados.interesado_op_interesado --$P!{datasetName}
   UNION SELECT op_interesado.local_id AS local_id ,
                (CASE
                     WHEN op_interesado.t_id IS NOT NULL THEN 'agrupacion'
                 END) AS agrupacion_interesado ,
                (coalesce(op_interesado.primer_nombre, '') || coalesce(' ' || op_interesado.segundo_nombre, '') || coalesce(' ' || op_interesado.primer_apellido, '') || coalesce(' ' || op_interesado.segundo_apellido, '') || coalesce(op_interesado.razon_social, '')) AS nombre
   FROM derecho_agrupacion_interesados
   LEFT JOIN ladmcol_2_9_6.op_interesado ON op_interesado.t_id = derecho_agrupacion_interesados.interesado_op_interesado
   ORDER BY local_id
   LIMIT 1)
SELECT info_predio.fmi ,
       info_predio.nupre ,
       info_predio.numero_predial ,
       info_predio.nombre ,
       info_predio.local_id ,
       info_predio.departamento ,
       info_predio.municipio ,
       --info_predio.zona ,
       info_predio.numero_predial_anterior ,
       info_terreno.area_terreno ,
       info_terreno.x ,
       info_terreno.y ,
       info_predio.codigo ,
       coalesce(info_interesado.nombre, 'no hay interesado') AS interesado_nombre ,
       info_interesado.agrupacion_interesado AS diferenciacion
FROM info_terreno ,
     info_predio ,
     info_interesado