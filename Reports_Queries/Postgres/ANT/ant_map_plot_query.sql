with
terrenos_seleccionados AS (
	SELECT lc_terreno.t_id AS ue_lc_terreno FROM ladm_lev_cat_v1.lc_terreno WHERE lc_terreno.t_id = 1432 -- parametrizar nombre schema, tablas, atributos y WHERE
),
predios_seleccionados AS (
    SELECT col_uebaunit.baunit AS t_id FROM ladm_lev_cat_v1.col_uebaunit WHERE col_uebaunit.ue_lc_terreno IN (SELECT lc_terreno.t_id AS ue_lc_terreno FROM ladm_lev_cat_v1.lc_terreno WHERE lc_terreno.t_id = 1432) -- parametrizar nombre schema, tablas, atributos y WHERE
),
derechos_seleccionados AS (
    SELECT DISTINCT lc_derecho.t_id FROM ladm_lev_cat_v1.lc_derecho WHERE lc_derecho.unidad IN (SELECT * FROM predios_seleccionados) -- parametrizar nombre schema, tablas, atributo
),
derecho_interesados AS (
    SELECT DISTINCT lc_derecho.interesado_lc_interesado, lc_derecho.t_id, lc_derecho.unidad AS predio_t_id FROM ladm_lev_cat_v1.lc_derecho WHERE lc_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND lc_derecho.interesado_lc_interesado IS NOT null -- parametrizar nombre schema, tablas, atributos
),
derecho_agrupacion_interesados AS (
    SELECT DISTINCT lc_derecho.interesado_lc_agrupacioninteresados, col_miembros.interesado_lc_interesado, col_miembros.agrupacion, lc_derecho.unidad AS predio_t_id -- parametrizar nombre schema, tablas, atributos
    FROM ladm_lev_cat_v1.lc_derecho LEFT JOIN ladm_lev_cat_v1.col_miembros ON lc_derecho.interesado_lc_agrupacioninteresados = col_miembros.agrupacion -- parametrizar nombre schema, tablas, atributos
    WHERE lc_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND lc_derecho.interesado_lc_agrupacioninteresados IS NOT null -- parametrizar nombre schema, tablas, atributos
),
info_predio AS (
    SELECT
        lc_predio.numero_predial AS numero_predial -- parametrizar tablas, atributos
        ,lc_predio.local_id AS local_id -- parametrizar tablas, atributos
        ,lc_predio.t_id -- parametrizar tablas, atributos
        FROM ladm_lev_cat_v1.lc_predio WHERE lc_predio.t_id IN (SELECT * FROM predios_seleccionados) --parametrizar schema, tablas, atributos
),
info_agrupacion_filter AS (
        SELECT DISTINCT ON (agrupacion) agrupacion
        ,lc_interesado.local_id AS local_id --parametrizar tablas, atributos
        ,predio_t_id
        ,(CASE WHEN lc_interesado.t_id is not null THEN 'agrupacion' END) AS agrupacion_interesado --parametrizar tablas, atributos
        ,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '') --parametrizar tablas, atributos
                || coalesce(lc_interesado.razon_social, '') ) AS nombre --parametrizar tablas, atributos
        FROM derecho_agrupacion_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_agrupacion_interesados.interesado_lc_interesado ORDER BY agrupacion --parametrizar schema, tablas, atributos
),
info_interesado AS (
        SELECT
        lc_interesado.local_id AS local_id --parametrizar tablas, atributos
        ,predio_t_id
        ,(CASE WHEN lc_interesado.t_id is not null THEN 'interesado' END) AS agrupacion_interesado --parametrizar tablas, atributos
        ,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '') --parametrizar tablas, atributos
                || coalesce(lc_interesado.razon_social, '') ) AS nombre --parametrizar tablas, atributos
        FROM derecho_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_interesados.interesado_lc_interesado --parametrizar tablas, atributos
),
info_agrupacion AS (
        SELECT local_id
        ,predio_t_id
        ,agrupacion_interesado
        ,nombre
        FROM info_agrupacion_filter
),
info_total_interesados AS (SELECT * FROM info_interesado union all SELECT * FROM info_agrupacion)
SELECT array_to_json(array_agg(features)) AS features
FROM (
    SELECT f AS features
    FROM (
        SELECT 'Feature' AS type
            ,row_to_json((
                SELECT l
                FROM (
                    SELECT (left(right(info_predio.numero_predial,15),6) || --parametrizar tablas, atributos
    (CASE WHEN info_total_interesados.agrupacion_interesado = 'agrupacion'
    THEN COALESCE(' ' || 'AGRUPACIÓN DE ' || info_total_interesados.nombre || ' Y OTROS', ' INDETERMINADO')
    ELSE COALESCE(' ' || info_total_interesados.nombre, ' INDETERMINADO') END)) AS predio
                    ) AS l
                )) AS properties
            ,ST_AsGeoJSON(lc_terreno.geometria, 4, 0)::json AS geometry
    FROM info_total_interesados
    JOIN info_predio ON info_predio.t_id = info_total_interesados.predio_t_id
    JOIN ladm_lev_cat_v1.col_uebaunit ON col_uebaunit.baunit = info_total_interesados.predio_t_id --parametrizar tablas, atributos
    JOIN ladm_lev_cat_v1.lc_terreno ON lc_terreno.t_id = col_uebaunit.ue_lc_terreno --parametrizar tablas, atributos
    ) AS f
) AS ff;