WITH
terreno_seleccionado AS (
	SELECT lc_terreno.t_id AS id_terreno FROM ladm_lev_cat_v1.lc_terreno
	WHERE lc_terreno.t_id = 955
),
predio_seleccionado AS (
	SELECT col_uebaunit.baunit AS t_id FROM ladm_lev_cat_v1.col_uebaunit JOIN terreno_seleccionado ON col_uebaunit.ue_lc_terreno = terreno_seleccionado.id_terreno LIMIT 1
),
derechos_seleccionados AS (
	SELECT DISTINCT lc_derecho.t_id FROM ladm_lev_cat_v1.lc_derecho WHERE lc_derecho.unidad IN (SELECT * FROM predio_seleccionado)
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
	    ,lc_predio.id_operacion
		,lc_predio.codigo_orip as orip
		,lc_predio.matricula_inmobiliaria AS fmi
		,lc_predio.nupre AS nupre
		,lc_predio.nombre AS nombre
		,lc_predio.local_id
		,lc_predio.departamento
		,lc_predio.municipio
		,lc_predio.numero_predial_anterior
		FROM ladm_lev_cat_v1.lc_predio WHERE lc_predio.t_id IN (SELECT * FROM predio_seleccionado)
),
info_agrupacion_filter AS (
	SELECT distinct on (agrupacion) agrupacion
	,predio_t_id
	,(case when lc_interesado.t_id is not null then 'agrupacion' end) AS agrupacion_interesado
	,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '') || coalesce(lc_interesado.razon_social, '') ) AS nombre
	,(select dispname from ladm_lev_cat_v1.lc_interesadodocumentotipo where  t_id = tipo_documento) tipo_documento
	,documento_identidad
	FROM derecho_agrupacion_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_agrupacion_interesados.interesado_lc_interesado order by agrupacion
),
info_interesado AS (
	SELECT DISTINCT
	predio_t_id
	,(case when lc_interesado.t_id is not null then 'interesado' end) AS agrupacion_interesado
	,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '') || coalesce(lc_interesado.razon_social, '') ) AS nombre
	, (select dispname from ladm_lev_cat_v1.lc_interesadodocumentotipo where  t_id = tipo_documento) tipo_documento
	, documento_identidad
	FROM derecho_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_interesados.interesado_lc_interesado
),
info_agrupacion AS (
		SELECT predio_t_id
		,agrupacion_interesado
		,nombre
	    ,tipo_documento
	    ,documento_identidad
		FROM info_agrupacion_filter
),
info_total_interesados AS (
	SELECT *  FROM info_interesado
	UNION ALL
	SELECT *  FROM info_agrupacion
)
SELECT case when info_predio.orip is null then info_predio.fmi else concat(COALESCE(info_predio.orip, ''), ' - ', COALESCE(info_predio.fmi, '')) end fmi
       ,info_predio.nupre
	   ,info_predio.id_operacion
       ,info_predio.numero_predial
       ,info_predio.nombre
       ,info_predio.departamento
       ,info_predio.municipio
	   ,(
		   select COALESCE(round(sum(st_area(geometria))::numeric, 2), 0)
		   from ladm_lev_cat_v1.lc_unidadconstruccion
		   where lc_construccion in (select col_uebaunit.ue_lc_construccion from ladm_lev_cat_v1.col_uebaunit where baunit = info_predio.t_id and col_uebaunit.ue_lc_construccion IS NOT NULL)
	   ) area_construida
	   ,(
		   SELECT
		   case when (SELECT dispname FROM ladm_lev_cat_v1.extdireccion_tipo_direccion WHERE t_id = extdireccion.tipo_direccion) = 'Estructurada' then
		   		trim(concat(COALESCE((SELECT dispname FROM ladm_lev_cat_v1.extdireccion_clase_via_principal WHERE t_id = extdireccion.clase_via_principal) || ' ', ''),
					 COALESCE(extdireccion.valor_via_principal || ' ', ''),
					 COALESCE(extdireccion.letra_via_principal || ' ', ''),
					 COALESCE((SELECT dispname FROM ladm_lev_cat_v1.extdireccion_sector_ciudad WHERE t_id = extdireccion.sector_ciudad) || ' ', ''),
					 COALESCE(extdireccion.valor_via_generadora || ' ', ''),
					 COALESCE(extdireccion.letra_via_generadora || ' ', ''),
					 COALESCE(extdireccion.numero_predio || ' ', ''),
					 COALESCE((SELECT dispname FROM ladm_lev_cat_v1.extdireccion_sector_predio WHERE t_id = extdireccion.sector_predio) || ' ', ''),
					 COALESCE(extdireccion.complemento || ' ', '')))
			else
				extdireccion.nombre_predio
			end
			from ladm_lev_cat_v1.extdireccion where extdireccion.lc_predio_direccion = info_predio.t_id
			limit 1) direccion
	   ,(
		   SELECT nombre
		   FROM ladm_lev_cat_v1.cc_corregimiento
		   WHERE st_intersects(geometria, terreno.geometria)
		   ORDER BY st_area(st_intersection(geometria, terreno.geometria)) desc
		   LIMIT 1) corregimiento
	   ,round(terreno.area_terreno, 2) area_terreno
	   ,(select round(Area_Registral_M2,2) from ladm_lev_cat_v1.lc_datosadicionaleslevantamientocatastral where lc_predio = info_predio.t_id) area_registral
	   ,info_total_interesados.tipo_documento
	   ,info_total_interesados.documento_identidad
       ,coalesce(info_total_interesados.nombre, 'no hay interesado') AS interesado_nombre
       ,info_total_interesados.agrupacion_interesado AS diferenciacion
	   ,CASE WHEN ST_NumGeometries(terreno.geometria) > 1 THEN true ELSE false END AS multiparte
	   ,ST_NumGeometries(terreno.geometria) AS num_partes
FROM (SELECT * FROM ladm_lev_cat_v1.lc_terreno where t_id in (select id_terreno from terreno_seleccionado)) AS terreno
LEFT JOIN ladm_lev_cat_v1.col_uebaunit ON terreno.t_id = col_uebaunit.ue_lc_terreno
LEFT JOIN info_predio ON col_uebaunit.baunit = info_predio.t_id
LEFT JOIN info_total_interesados ON info_predio.t_id = info_total_interesados.predio_t_id
LIMIT 1