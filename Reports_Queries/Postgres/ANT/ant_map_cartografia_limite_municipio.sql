WITH
limite_municipio AS (SELECT geometria AS geom , codigo_municipio || ' ' ||nombre_municipio as nombre_municipio FROM cali.cc_limitemunicipio
					 WHERE geometria && (SELECT ST_Expand(ST_Envelope(geometria), 1000) FROM cali.lc_terreno WHERE t_id = 22645) AND
					 NOT ST_Contains(geometria, (SELECT geometria FROM cali.lc_terreno WHERE t_id = 22645))
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