with
				terrenos_seleccionados AS (
					(SELECT lc_terreno.t_id as ue_lc_terreno from ladm_lev_cat_v1.lc_terreno where lc_terreno.t_id = 1522) -- parametrizar nombre schema, tablas, atributos y WHERE
				),
				predios_seleccionados AS (
					SELECT col_uebaunit.baunit as t_id FROM ladm_lev_cat_v1.col_uebaunit WHERE col_uebaunit.ue_lc_terreno in (SELECT lc_terreno.t_id as ue_lc_terreno from ladm_lev_cat_v1.lc_terreno where lc_terreno.t_id = 1522) -- parametrizar nombre schema, tablas, atributos y WHERE
				),
				derechos_seleccionados AS (
					SELECT DISTINCT lc_derecho.t_id FROM ladm_lev_cat_v1.lc_derecho WHERE lc_derecho.unidad IN (SELECT * FROM predios_seleccionados) -- parametrizar nombre schema, tablas, atributo
				),
				derecho_interesados AS (
					SELECT DISTINCT lc_derecho.interesado_lc_interesado, lc_derecho.t_id, lc_derecho.unidad as predio_t_id FROM ladm_lev_cat_v1.lc_derecho WHERE lc_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND lc_derecho.interesado_lc_interesado IS NOT null -- parametrizar nombre schema, tablas, atributos
				),
				derecho_agrupacion_interesados AS (
					SELECT DISTINCT lc_derecho.interesado_lc_agrupacioninteresados, col_miembros.interesado_lc_interesado, col_miembros.agrupacion, lc_derecho.unidad as predio_t_id -- parametrizar nombre schema, tablas, atributos
					FROM ladm_lev_cat_v1.lc_derecho LEFT JOIN ladm_lev_cat_v1.col_miembros ON lc_derecho.interesado_lc_agrupacioninteresados = col_miembros.agrupacion -- parametrizar nombre schema, tablas, atributos
					WHERE lc_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND lc_derecho.interesado_lc_agrupacioninteresados IS NOT null -- parametrizar nombre schema, tablas, atributos
				),
				info_predio as (
					select
						lc_predio.numero_predial as numero_predial -- parametrizar tablas, atributos
						,lc_predio.local_id as local_id -- parametrizar tablas, atributos
						,lc_predio.t_id -- parametrizar tablas, atributos
						from ladm_lev_cat_v1.lc_predio where lc_predio.t_id IN (SELECT * FROM predios_seleccionados) --parametrizar schema, tablas, atributos
				),
				info_agrupacion_filter as (
						select distinct on (agrupacion) agrupacion
						,lc_interesado.local_id as local_id --parametrizar tablas, atributos
						,predio_t_id
						,(case when lc_interesado.t_id is not null then 'agrupacion' end) as agrupacion_interesado --parametrizar tablas, atributos
						,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '') --parametrizar tablas, atributos
								|| coalesce(lc_interesado.razon_social, '') ) as nombre --parametrizar tablas, atributos
						from derecho_agrupacion_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_agrupacion_interesados.interesado_lc_interesado order by agrupacion --parametrizar schema, tablas, atributos
				),
				info_interesado as (
						select
						lc_interesado.local_id as local_id --parametrizar tablas, atributos
						,predio_t_id
						,(case when lc_interesado.t_id is not null then 'interesado' end) as agrupacion_interesado --parametrizar tablas, atributos
						,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '') --parametrizar tablas, atributos
								|| coalesce(lc_interesado.razon_social, '') ) as nombre --parametrizar tablas, atributos
						from derecho_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_interesados.interesado_lc_interesado --parametrizar tablas, atributos
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
												,ST_AsGeoJSON(lc_terreno.geometria)::json AS geometry
								FROM info_total_interesados
								join info_predio on info_predio.t_id = info_total_interesados.predio_t_id
								join ladm_lev_cat_v1.col_uebaunit on col_uebaunit.baunit = info_total_interesados.predio_t_id --parametrizar tablas, atributos
								join ladm_lev_cat_v1.lc_terreno on lc_terreno.t_id = col_uebaunit.ue_lc_terreno --parametrizar tablas, atributos
								) AS f
                             ) AS ff;