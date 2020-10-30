WITH
limite_municipio AS (SELECT geometria AS geom , nombre_municipio FROM reportes_el_guamo.cc_limitemunicipio
					 WHERE geometria && (SELECT ST_Expand(ST_Envelope(geometria), 1000) FROM reportes_el_guamo.lc_terreno WHERE t_id = 956))
SELECT array_to_json(array_agg(features)) AS features
FROM (
	SELECT f AS features
	FROM (
		SELECT 'Feature' AS type,
		row_to_json((SELECT l FROM (SELECT nombre_municipio) AS l)) AS properties,
		ST_AsGeoJSON(geom, 4, 0)::json AS geometry
		FROM limite_municipio
	) AS f)
AS ff;