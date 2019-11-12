SELECT array_to_json(array_agg(features)) AS features
                    FROM (
                    	SELECT f AS features
                    	FROM (
                    		SELECT 'Feature' AS type
                    			,ST_AsGeoJSON(geometria)::json AS geometry --Parametrizar geometria
                    			,row_to_json((
                    					SELECT l
                    					FROM (
                    						SELECT t_id AS t_id
                    						) AS l
                    					)) AS properties
                            FROM ladmcol_2_9_6.op_construccion AS c --Parametrizar schema y nombre de tabla
                    		) AS f
                        ) AS ff