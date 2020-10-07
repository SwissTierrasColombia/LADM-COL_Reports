WITH
terrenos_seleccionados AS (
    -- The selection of the filter depends on: If you want a selected plot or all associated plots
	SELECT lc_terreno.t_id AS ue_lc_terreno FROM ladm_lev_cat_v1.lc_terreno
	 WHERE lc_terreno.t_id = 1432
	 --WHERE lc_terreno.geometria && (SELECT ST_Expand(ST_Envelope(lc_terreno.geometria), 200) FROM ladm_lev_cat_v1.lc_terreno WHERE t_id = 1432) AND lc_terreno.t_id != 1432
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
        ,lc_predio.local_id AS local_id
        ,lc_predio.t_id
        FROM ladm_lev_cat_v1.lc_predio WHERE lc_predio.t_id IN (SELECT * FROM predios_seleccionados)
),
info_agrupacion_filter AS (
        SELECT DISTINCT ON (agrupacion) agrupacion
        ,predio_t_id
        ,(CASE WHEN lc_interesado.t_id is not null THEN 'agrupacion' END) AS agrupacion_interesado 
        ,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '') 
                || coalesce(lc_interesado.razon_social, '') ) AS nombre 
        FROM derecho_agrupacion_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_agrupacion_interesados.interesado_lc_interesado ORDER BY agrupacion
),
info_interesado AS (
        SELECT DISTINCT
        predio_t_id
        ,(CASE WHEN lc_interesado.t_id is not null THEN 'interesado' END) AS agrupacion_interesado 
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
	SELECT * FROM info_interesado
	UNION ALL
	SELECT * FROM info_agrupacion
)
SELECT array_to_json(array_agg(features)) AS features
FROM (
SELECT f AS features
FROM (
    SELECT 'Feature' AS type ,row_to_json((
        SELECT l
            FROM (
                SELECT (left(right(info_predio.numero_predial,15),6) ||
                (CASE WHEN info_total_interesados.agrupacion_interesado = 'agrupacion'
                THEN COALESCE(' ' || 'AGRUPACIÓN DE ' || info_total_interesados.nombre || ' Y OTROS', ' INDETERMINADO')
                ELSE COALESCE(' ' || info_total_interesados.nombre, ' INDETERMINADO') END)) AS predio
            ) AS l)) AS properties
            ,ST_AsGeoJSON(terrenos.geometria, 4, 0)::json AS geometry
        FROM (SELECT * FROM ladm_lev_cat_v1.lc_terreno where t_id in (select ue_lc_terreno from terrenos_seleccionados)) AS terrenos
        LEFT JOIN ladm_lev_cat_v1.col_uebaunit ON terrenos.t_id = col_uebaunit.ue_lc_terreno
        LEFT JOIN info_predio ON col_uebaunit.baunit = info_predio.t_id
        LEFT JOIN info_total_interesados ON info_predio.t_id = info_total_interesados.predio_t_id
    ) AS f
) AS ff;