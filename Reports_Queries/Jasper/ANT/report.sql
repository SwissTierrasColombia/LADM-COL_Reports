WITH terrenos_seleccionados AS
  (SELECT 1522 AS ue_terreno --$P{id}
   WHERE '764' <> 'NULL' --12425  12424 12005
   UNION SELECT col_uebaunit.ue_lc_terreno
   FROM ladm_lev_cat_v1.lc_predio
   LEFT JOIN ladm_lev_cat_v1.col_uebaunit ON lc_predio.t_id = col_uebaunit.baunit
   WHERE col_uebaunit.ue_lc_terreno IS NOT NULL
     AND CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE lc_predio.matricula_inmobiliaria = 'NULL'
         END
   UNION SELECT col_uebaunit.ue_lc_terreno
   FROM ladm_lev_cat_v1.lc_predio
   LEFT JOIN ladm_lev_cat_v1.col_uebaunit ON lc_predio.t_id = col_uebaunit.baunit
   WHERE col_uebaunit.ue_lc_terreno IS NOT NULL
     AND CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE lc_predio.numero_predial = 'NULL'
         END
   UNION SELECT col_uebaunit.ue_lc_terreno
   FROM ladm_lev_cat_v1.lc_predio
   LEFT JOIN ladm_lev_cat_v1.col_uebaunit ON lc_predio.t_id = col_uebaunit.baunit
   WHERE col_uebaunit.ue_lc_terreno IS NOT NULL
     AND CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE lc_predio.numero_predial_anterior = 'NULL'
         END ),
     predios_seleccionados AS
  (SELECT col_uebaunit.baunit AS t_id
   FROM ladm_lev_cat_v1.col_uebaunit
   WHERE col_uebaunit.ue_lc_terreno = 1522--$P{id}
     AND '764' <> 'NULL'
   UNION SELECT t_id
   FROM ladm_lev_cat_v1.lc_predio
   WHERE CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE lc_predio.matricula_inmobiliaria = 'NULL'
         END
   UNION SELECT t_id
   FROM ladm_lev_cat_v1.lc_predio
   WHERE CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE lc_predio.numero_predial = 'NULL'
         END
   UNION SELECT t_id
   FROM ladm_lev_cat_v1.lc_predio
   WHERE CASE
             WHEN 'NULL' = 'NULL' THEN 1 = 2
             ELSE lc_predio.numero_predial_anterior = 'NULL'
         END ),
     derechos_seleccionados AS
  (SELECT DISTINCT lc_derecho.t_id
   FROM ladm_lev_cat_v1.lc_derecho
   WHERE lc_derecho.unidad IN
       (SELECT *
        FROM predios_seleccionados) ),
     derecho_interesados AS
  (SELECT DISTINCT lc_derecho.interesado_lc_interesado,
                   lc_derecho.t_id
   FROM ladm_lev_cat_v1.lc_derecho
   WHERE lc_derecho.t_id IN
       (SELECT *
        FROM derechos_seleccionados)
     AND lc_derecho.interesado_lc_interesado IS NOT NULL ),
     derecho_agrupacion_interesados AS
  (SELECT DISTINCT lc_derecho.interesado_lc_agrupacioninteresados,
                   col_miembros.interesado_lc_interesado
   FROM ladm_lev_cat_v1.lc_derecho
   LEFT JOIN ladm_lev_cat_v1.col_miembros ON lc_derecho.interesado_lc_agrupacioninteresados = col_miembros.agrupacion
   WHERE lc_derecho.t_id IN
       (SELECT *
        FROM derechos_seleccionados)
     AND lc_derecho.interesado_lc_agrupacioninteresados IS NOT NULL ),
     info_terreno AS
  (SELECT lc_terreno.area_terreno,
          st_x(st_transform(st_centroid(lc_terreno.geometria), 4326)) AS x ,
          st_y(st_transform(st_centroid(geometria), 4326)) AS y
   FROM ladm_lev_cat_v1.lc_terreno
   WHERE lc_terreno.t_id IN
       (SELECT *
        FROM terrenos_seleccionados) ),
     info_predio AS
  (SELECT lc_predio.matricula_inmobiliaria AS fmi ,
          lc_predio.nupre AS nupre ,
          lc_predio.numero_predial AS numero_predial ,
          lc_predio.nombre AS nombre ,
          lc_predio.local_id ,
          lc_predio.departamento ,
          lc_predio.municipio ,
          --lc_predio.zona ,
          lc_predio.numero_predial_anterior ,
          lc_predio.espacio_de_nombres || lc_predio.local_id AS codigo
   FROM ladm_lev_cat_v1.lc_predio
   WHERE lc_predio.t_id IN
       (SELECT *
        FROM predios_seleccionados) ),
     info_interesado AS
  (SELECT lc_interesado.local_id AS local_id ,
          (CASE
               WHEN lc_interesado.t_id IS NOT NULL THEN 'interesado'
           END) AS agrupacion_interesado ,
          (coalesce(lc_interesado.primer_nombre, '') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '') || coalesce(lc_interesado.razon_social, '')) AS nombre
   FROM derecho_interesados
   LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_interesados.interesado_lc_interesado
   UNION SELECT lc_interesado.local_id AS local_id ,
                (CASE
                     WHEN lc_interesado.t_id IS NOT NULL THEN 'agrupacion'
                 END) AS agrupacion_interesado ,
                (coalesce(lc_interesado.primer_nombre, '') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '') || coalesce(lc_interesado.razon_social, '')) AS nombre
   FROM derecho_agrupacion_interesados
   LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_agrupacion_interesados.interesado_lc_interesado
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