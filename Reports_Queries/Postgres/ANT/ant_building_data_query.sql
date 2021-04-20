WITH
predio as (
	select baunit from rubi.col_uebaunit
	where col_uebaunit.ue_lc_terreno = 2378
),
construcciones_predio as (
	select ue_lc_construccion from rubi.col_uebaunit
	where col_uebaunit.baunit in (select * from predio) and ue_lc_construccion is not Null
)
SELECT array_to_json(array_agg(features)) AS features
FROM (
SELECT f AS features
	FROM (
		SELECT 'Feature' AS type
			,ST_AsGeoJSON(geometria, 4, 0)::json AS geometry --Parametrizar geometria
			,row_to_json((SELECT l FROM (SELECT t_id AS t_id) AS l)) AS properties
		FROM rubi.lc_construccion 
		WHERE t_id in (select * from construcciones_predio)
	) AS f
) AS ff;
