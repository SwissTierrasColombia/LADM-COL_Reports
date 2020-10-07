WITH
terrenos_seleccionados AS (
	SELECT lc_terreno.t_id AS ue_lc_terreno FROM ladm_lev_cat_v1.lc_terreno
--	WHERE lc_terreno.geometria && (SELECT ST_Expand(ST_Envelope(lc_terreno.geometria), 200) FROM ladm_lev_cat_v1.lc_terreno WHERE t_id = 1432)
	WHERE lc_terreno.t_id = 1458
),
predios_seleccionados AS (
	SELECT col_uebaunit.baunit AS t_id FROM ladm_lev_cat_v1.col_uebaunit JOIN terrenos_seleccionados ON col_uebaunit.ue_lc_terreno = terrenos_seleccionados.ue_lc_terreno
),
derechos_seleccionados AS (
	SELECT DISTINCT lc_derecho.t_id FROM ladm_lev_cat_v1.lc_derecho WHERE lc_derecho.unidad IN (SELECT * FROM predios_seleccionados)
),
derecho_interesados AS (
	SELECT DISTINCT lc_derecho.interesado_lc_interesado, lc_derecho.t_id, lc_derecho.unidad AS predio_t_id FROM ladm_lev_cat_v1.lc_derecho WHERE lc_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND lc_derecho.interesado_lc_interesado IS NOT NULL
),
derecho_agrupacion_interesados AS (
	SELECT DISTINCT lc_derecho.interesado_lc_agrupacioninteresados, col_miembros.interesado_lc_interesado, col_miembros.agrupacion, lc_derecho.unidad AS predio_t_id
	FROM ladm_lev_cat_v1.lc_derecho LEFT JOIN ladm_lev_cat_v1.col_miembros ON lc_derecho.interesado_lc_agrupacioninteresados = col_miembros.agrupacion
	WHERE lc_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND lc_derecho.interesado_lc_agrupacioninteresados IS NOT NULL
),
info_predio AS (
	SELECT
		lc_predio.numero_predial AS numero_predial
		,lc_predio.t_id
		,lc_predio.matricula_inmobiliaria AS fmi
		,lc_predio.nupre AS nupre
		,lc_predio.nombre AS nombre
		,lc_predio.local_id
		,lc_predio.departamento
		,lc_predio.municipio
		--,lc_predio.zona
		,lc_predio.numero_predial_anterior
		,lc_predio.espacio_de_nombres || lc_predio.local_id AS codigo
		FROM ladm_lev_cat_v1.lc_predio WHERE lc_predio.t_id IN (SELECT * FROM predios_seleccionados)
),
info_agrupacion_filter AS (
	SELECT distinct on (agrupacion) agrupacion
	,predio_t_id
	,(case when lc_interesado.t_id is not null then 'agrupacion' end) AS agrupacion_interesado
	,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '')
			|| coalesce(lc_interesado.razon_social, '') ) AS nombre
	FROM derecho_agrupacion_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_agrupacion_interesados.interesado_lc_interesado order by agrupacion
),
info_interesado AS (
	SELECT DISTINCT
	predio_t_id
	,(case when lc_interesado.t_id is not null then 'interesado' end) AS agrupacion_interesado
	,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '')
			|| coalesce(lc_interesado.razon_social, '') ) AS nombre
	FROM derecho_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_interesados.interesado_lc_interesado
),
info_agrupacion AS (
		SELECT predio_t_id
		,agrupacion_interesado
		,nombre
		FROM info_agrupacion_filter
),
info_total_interesados AS (
	SELECT *  FROM info_interesado
	UNION ALL
	SELECT *  FROM info_agrupacion
)
SELECT info_predio.fmi
       ,info_predio.nupre
       ,info_predio.numero_predial
       ,info_predio.nombre
       ,info_predio.local_id
       ,info_predio.departamento
       ,info_predio.municipio
       --,info_predio.zona
       ,info_predio.numero_predial_anterior
	   ,terreno.area_terreno
	   ,st_x(st_transform(st_centroid(terreno.geometria), 4326)) AS x
	   ,st_y(st_transform(st_centroid(terreno.geometria), 4326)) AS y
	   ,info_predio.codigo
       ,coalesce(info_total_interesados.nombre, 'no hay interesado') AS interesado_nombre
       ,info_total_interesados.agrupacion_interesado AS diferenciacion
FROM (SELECT * FROM ladm_lev_cat_v1.lc_terreno where t_id in (select ue_lc_terreno from terrenos_seleccionados)) AS terreno
LEFT JOIN ladm_lev_cat_v1.col_uebaunit ON terreno.t_id = col_uebaunit.ue_lc_terreno
LEFT JOIN info_predio ON col_uebaunit.baunit = info_predio.t_id
LEFT JOIN info_total_interesados ON info_predio.t_id = info_total_interesados.predio_t_id