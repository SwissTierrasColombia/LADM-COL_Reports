SELECT array_to_json(array_agg(features)) AS features
                    FROM (
                        SELECT f AS features
                        FROM (
                            SELECT 'Feature' AS type
                                ,row_to_json((
                                    SELECT l
                                    FROM (
                                        SELECT left(right(numero_predial,15),6) AS predio --parametrizar atributo numero_predial
                                        ) AS l
                                    )) AS properties
                                ,ST_AsGeoJSON(geometria)::json AS geometry --parametrizar geometria
                            FROM ladmcol_2_9_6.op_terreno AS l --parametrizar schema y tabla
                            LEFT JOIN ladmcol_2_9_6.col_uebaunit ON l.t_id = ue_op_terreno --parametrizar schema, tabla y atributo
                            LEFT JOIN ladmcol_2_9_6.op_predio ON op_predio.t_id = baunit --parametrizar schema, tabla y atributo
                            where l.t_id = 1522 --parametrizar where
                            ) AS f
                        ) AS ff;