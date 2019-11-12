with
				terrenos_seleccionados AS (
					(SELECT op_terreno.t_id as ue_op_terreno from ladmcol_2_9_6.op_terreno where op_terreno.t_id = 1522) -- parametrizar nombre schema, tablas, atributos y WHERE
				),
				predios_seleccionados AS (
					SELECT col_uebaunit.baunit as t_id FROM ladmcol_2_9_6.col_uebaunit WHERE col_uebaunit.ue_op_terreno in (SELECT op_terreno.t_id as ue_op_terreno from ladmcol_2_9_6.op_terreno where op_terreno.t_id = 1522) -- parametrizar nombre schema, tablas, atributos y WHERE
				),
				derechos_seleccionados AS (
					SELECT DISTINCT op_derecho.t_id FROM ladmcol_2_9_6.op_derecho WHERE op_derecho.unidad IN (SELECT * FROM predios_seleccionados) -- parametrizar nombre schema, tablas, atributo
				),
				derecho_interesados AS (
					SELECT DISTINCT op_derecho.interesado_op_interesado, op_derecho.t_id, op_derecho.unidad as predio_t_id FROM ladmcol_2_9_6.op_derecho WHERE op_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND op_derecho.interesado_op_interesado IS NOT null -- parametrizar nombre schema, tablas, atributos
				),
				derecho_agrupacion_interesados AS (
					SELECT DISTINCT op_derecho.interesado_op_agrupacion_interesados, col_miembros.interesado_op_interesado, col_miembros.agrupacion, op_derecho.unidad as predio_t_id -- parametrizar nombre schema, tablas, atributos
					FROM ladmcol_2_9_6.op_derecho LEFT JOIN ladmcol_2_9_6.col_miembros ON op_derecho.interesado_op_agrupacion_interesados = col_miembros.agrupacion -- parametrizar nombre schema, tablas, atributos
					WHERE op_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND op_derecho.interesado_op_agrupacion_interesados IS NOT null -- parametrizar nombre schema, tablas, atributos
				),
				info_predio as (
					select
						op_predio.numero_predial as numero_predial -- parametrizar tablas, atributos
						,op_predio.local_id as local_id -- parametrizar tablas, atributos
						,op_predio.t_id -- parametrizar tablas, atributos
						from ladmcol_2_9_6.op_predio where op_predio.t_id IN (SELECT * FROM predios_seleccionados) --parametrizar schema, tablas, atributos
				),
				info_agrupacion_filter as (
						select distinct on (agrupacion) agrupacion
						,op_interesado.local_id as local_id --parametrizar tablas, atributos
						,predio_t_id
						,(case when op_interesado.t_id is not null then 'agrupacion' end) as agrupacion_interesado --parametrizar tablas, atributos
						,(coalesce(op_interesado.primer_nombre,'') || coalesce(' ' || op_interesado.segundo_nombre, '') || coalesce(' ' || op_interesado.primer_apellido, '') || coalesce(' ' || op_interesado.segundo_apellido, '') --parametrizar tablas, atributos
								|| coalesce(op_interesado.razon_social, '') ) as nombre --parametrizar tablas, atributos
						from derecho_agrupacion_interesados LEFT JOIN ladmcol_2_9_6.op_interesado ON op_interesado.t_id = derecho_agrupacion_interesados.interesado_op_interesado order by agrupacion --parametrizar schema, tablas, atributos
				),
				info_interesado as (
						select
						op_interesado.local_id as local_id --parametrizar tablas, atributos
						,predio_t_id
						,(case when op_interesado.t_id is not null then 'interesado' end) as agrupacion_interesado --parametrizar tablas, atributos
						,(coalesce(op_interesado.primer_nombre,'') || coalesce(' ' || op_interesado.segundo_nombre, '') || coalesce(' ' || op_interesado.primer_apellido, '') || coalesce(' ' || op_interesado.segundo_apellido, '') --parametrizar tablas, atributos
								|| coalesce(op_interesado.razon_social, '') ) as nombre --parametrizar tablas, atributos
						from derecho_interesados LEFT JOIN ladmcol_2_9_6.op_interesado ON op_interesado.t_id = derecho_interesados.interesado_op_interesado --parametrizar tablas, atributos
				),
				info_agrupacion as (
						select local_id
						,predio_t_id
						,agrupacion_interesado
						,nombre
						from info_agrupacion_filter
				),
				info_total_interesados as (select * from info_interesado union all select * from info_agrupacion)
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
												,ST_AsGeoJSON(op_terreno.geometria)::json AS geometry
								FROM info_total_interesados
								join info_predio on info_predio.t_id = info_total_interesados.predio_t_id
								join ladmcol_2_9_6.col_uebaunit on col_uebaunit.baunit = info_total_interesados.predio_t_id --parametrizar tablas, atributos
								join ladmcol_2_9_6.op_terreno on op_terreno.t_id = col_uebaunit.ue_op_terreno --parametrizar tablas, atributos
								) AS f
                             ) AS ff;