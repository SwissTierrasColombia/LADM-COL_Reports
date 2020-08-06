WITH
parametros AS (
  SELECT
    1432 	AS terreno_t_id --$P{id}
),
t AS (
	SELECT t_id, ST_ForceRHR(geometria) AS geometria FROM ladm_lev_cat_v1.lc_terreno WHERE t_id = (SELECT terreno_t_id FROM parametros)
),
linderos AS (
	SELECT lc_lindero.t_id, lc_lindero.geometria AS geom  FROM ladm_lev_cat_v1.lc_lindero JOIN ladm_lev_cat_v1.col_masccl ON col_masccl.ue_mas_lc_terreno = (SELECT terreno_t_id FROM parametros) AND lc_lindero.t_id = col_masccl.ccl_mas
),
terrenos_asociados_linderos AS (
	SELECT DISTINCT col_masccl.ue_mas_lc_terreno AS t_id_terreno, col_masccl.ccl_mas AS t_id_lindero FROM ladm_lev_cat_v1.col_masccl WHERE col_masccl.ccl_mas IN (SELECT t_id FROM linderos) AND col_masccl.ue_mas_lc_terreno != (SELECT terreno_t_id FROM parametros)
),
lineas_colindancia AS (
	SELECT t_id_terreno AS t_id, linderos.geom FROM linderos JOIN terrenos_asociados_linderos ON linderos.t_id = terrenos_asociados_linderos.t_id_lindero
)
SELECT array_to_json(array_agg(features)) AS features
FROM (
	SELECT f AS features
	FROM (
		SELECT 'Feature' AS type,
		row_to_json((SELECT l FROM (SELECT ROUND(st_length(lineas_colindancia.geom)::numeric, 2) AS longitud) AS l)) AS properties,
		ST_AsGeoJSON(lineas_colindancia.geom)::json AS geometry
		FROM lineas_colindancia
	) as f)
as ff;