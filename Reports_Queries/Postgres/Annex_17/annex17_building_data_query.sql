SELECT array_to_json(array_agg(features)) AS features
                    FROM (
                    	SELECT f AS features
                    	FROM (
                    		SELECT 'Feature' AS type
                    			,ST_AsGeoJSON(geometria, 4, 0)::json AS geometry --Parametrizar geometria
                    			,row_to_json((
                    					SELECT l
                    					FROM (
                    						SELECT t_id AS t_id
                    						) AS l
                    					)) AS properties
                            FROM ladm_lev_cat_v1.lc_construccion AS c --Parametrizar schema y nombre de tabla
                            WHERE geometria && (SELECT ST_Expand(ST_Envelope(lc_terreno.geometria), 200) FROM ladm_lev_cat_v1.lc_terreno WHERE t_id = 1432)
                    		) AS f
                        ) AS ff