WITH
nomenclatura_vial AS (
	SELECT (SELECT dispname FROM reportes_el_guamo.cc_nomenclaturavial_tipo_via WHERE t_id = tipo_via) || ' ' || numero_via AS nombre, geometria AS geom FROM reportes_el_guamo.cc_nomenclaturavial
	WHERE geometria && (SELECT ST_Expand(ST_Envelope(geometria), 200) FROM reportes_el_guamo.lc_terreno WHERE t_id = 956)
)
SELECT array_to_json(array_agg(features)) AS features
FROM (
	SELECT f AS features
	FROM (
		SELECT 'Feature' AS type,
		row_to_json((SELECT l FROM (SELECT nombre) AS l)) AS properties,
		ST_AsGeoJSON(geom, 4, 0)::json AS geometry
		FROM nomenclatura_vial
	) AS f)
AS ff;