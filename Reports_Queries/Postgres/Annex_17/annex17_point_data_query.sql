WITH
-- Se definen los parametos de la consulta
parametros AS (
  SELECT
    1458 	AS terreno_t_id, --$P{id}
     1 		AS criterio_punto_inicial, --tipo de criterio para seleccionar el punto inicial de la enumeración del terreno, valores posibles: 1 (punto mas cercano al noroeste), 2 (punto mas cercano al noreste) parametrizar $P{criterio_punto_inicial}
     4		AS criterio_observador --1: Centroide, 2: Centro del extent, 3: punto en la superficie, 4: Punto mas cercano al centroide dentro del poligono
),
-- Se orienta en terreno en el sentido de las manecillas del reloj
t AS (
	SELECT t_id, ST_ForceRHR(geometria) AS geometria FROM ladm_lev_cat_v1.lc_terreno WHERE t_id = (SELECT terreno_t_id FROM parametros)
),
-- Se obtienen los vertices del bbox del terreno general (multiparte)
punto_nw_g AS (
	SELECT ST_SetSRID(ST_MakePoint(st_xmin(t.geometria), st_ymax(t.geometria)), ST_SRID(t.geometria)) AS p FROM t
),
punto_ne_g AS (
	SELECT ST_SetSRID(ST_MakePoint(st_xmax(t.geometria), st_ymax(t.geometria)), ST_SRID(t.geometria)) AS p FROM t
),
punto_se_g AS (
	SELECT ST_SetSRID(ST_MakePoint(st_xmax(t.geometria), st_ymin(t.geometria)), ST_SRID(t.geometria)) AS p FROM t
),
punto_sw_g AS (
	SELECT ST_SetSRID(ST_MakePoint(st_xmin(t.geometria), st_ymin(t.geometria)), ST_SRID(t.geometria)) AS p FROM t
),
-- Se obtiene el punto medio (ubicación del observador para la definicion de las cardinalidades) del terreno general (multiparte)
punto_medio_g AS (
  SELECT
    CASE WHEN criterio_observador = 1 THEN  --centroide del poligono
      ( SELECT ST_SetSRID(ST_MakePoint(st_x(ST_centroid(t.geometria)), st_y(ST_centroid(t.geometria))), ST_SRID(t.geometria)) AS p FROM t )
    WHEN criterio_observador = 2 THEN   --Centro del extent
      ( SELECT ST_SetSRID(ST_MakePoint(st_x(ST_centroid(st_envelope(t.geometria))), st_y(ST_centroid(st_envelope(t.geometria)))), ST_SRID(t.geometria)) AS p FROM t )
    WHEN criterio_observador = 3 THEN  --Punto en la superficie
      ( SELECT ST_SetSRID(ST_PointOnSurface(geometria), ST_SRID(t.geometria)) AS p FROM t )
    WHEN criterio_observador = 4 THEN  --Punto mas cercano al centroide pero que se intersecte el poligono si esta fuera
      ( SELECT ST_SetSRID(ST_MakePoint(st_x( ST_ClosestPoint( geometria, ST_centroid(t.geometria))), st_y( ST_ClosestPoint( geometria,ST_centroid(t.geometria)))), ST_SRID(t.geometria)) AS p FROM t )
    ELSE  --defecto: Centro del extent
      ( SELECT ST_SetSRID(ST_MakePoint(st_x(ST_centroid(st_envelope(t.geometria))), st_y(ST_centroid(st_envelope(t.geometria)))), ST_SRID(t.geometria)) AS p FROM t )
    END AS p
    FROM parametros
),
-- Se cuadrantes del terreno general (multiparte)
cuadrante_norte_g AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [punto_nw_g.p, punto_ne_g.p, punto_medio_g.p, punto_nw_g.p])), ST_SRID(t.geometria)) geom FROM t, punto_nw_g, punto_ne_g, punto_medio_g
),
cuadrante_este_g AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [punto_medio_g.p, punto_ne_g.p, punto_se_g.p, punto_medio_g.p])), ST_SRID(t.geometria)) geom FROM t, punto_ne_g, punto_se_g, punto_medio_g
),
cuadrante_sur_g AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [punto_medio_g.p, punto_se_g.p, punto_sw_g.p, punto_medio_g.p])), ST_SRID(t.geometria)) geom FROM t, punto_medio_g, punto_se_g, punto_sw_g
),
cuadrante_oeste_g AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [punto_nw_g.p, punto_medio_g.p, punto_sw_g.p, punto_nw_g.p])), ST_SRID(t.geometria)) geom FROM t, punto_nw_g, punto_medio_g, punto_sw_g
),
cuadrantes_g AS (
	SELECT 'Norte' ubicacion, geom AS cuadrante FROM cuadrante_norte_g
	UNION
	SELECT 'Este' ubicacion, geom AS cuadrante FROM cuadrante_este_g
	UNION
	SELECT 'Sur' ubicacion, geom AS cuadrante FROM cuadrante_sur_g
	UNION
	SELECT 'Oeste' ubicacion, geom AS cuadrante FROM cuadrante_oeste_g
),
-- Se convierte la geometria multipoligono del terreno a partes simples
t_simple AS (
	SELECT t_id, (ST_Dump(geometria)).path[1] as parte, ST_ForceRHR((ST_Dump(geometria)).geom) as geom FROM ladm_lev_cat_v1.lc_terreno WHERE t_id = (SELECT terreno_t_id FROM parametros)
),
-- Se ordenan las partes del terreno empezando por la más cercana a la esquina noroeste del terreno general
t_simple_ordenado as (
	select row_number() OVER () as parte, t_id, geom
	from (
		select t_id, geom, st_distance(t_simple.geom, punto_nw_g.p) as dist from t_simple, punto_nw_g order by dist
	) as l
),
-- Se obtienen los vertices del bbox de cada parte del terreno
vertices_bbox_partes AS (
	select t_simple_ordenado.*,
	   ST_SetSRID(ST_MakePoint(st_xmin(geom), st_ymax(geom)), ST_SRID(geom)) as p_nw,
	   ST_SetSRID(ST_MakePoint(st_xmax(geom), st_ymax(geom)), ST_SRID(geom)) as p_ne,
	   ST_SetSRID(ST_MakePoint(st_xmax(geom), st_ymin(geom)), ST_SRID(geom)) as p_se,
	   ST_SetSRID(ST_MakePoint(st_xmin(geom), st_ymin(geom)), ST_SRID(geom)) as p_sw,
	   CASE WHEN criterio_observador = 1 THEN  --centroide del poligono
	   		ST_SetSRID(ST_MakePoint(st_x(ST_centroid(geom)), st_y(ST_centroid(geom))), ST_SRID(geom))
		WHEN criterio_observador = 2 THEN  --Centro del extent
		  	ST_SetSRID(ST_MakePoint(st_x(ST_centroid(st_envelope(geom))), st_y(ST_centroid(st_envelope(geom)))), ST_SRID(geom))
		WHEN criterio_observador = 3 THEN  --Punto en la superficie
		  	ST_SetSRID(ST_PointOnSurface(geom), ST_SRID(geom))
		WHEN criterio_observador = 4 THEN  --Punto mas cercano al centroide pero que se intersecte el poligono si esta fuera
		  	ST_SetSRID(ST_MakePoint(st_x(ST_ClosestPoint(geom, ST_centroid(geom))), st_y( ST_ClosestPoint(geom,ST_centroid(geom)))), ST_SRID(geom))
		ELSE  --defecto: Centro del extent
		  	ST_SetSRID(ST_MakePoint(st_x(ST_centroid(st_envelope(geom))), st_y(ST_centroid(st_envelope(geom)))), ST_SRID(geom))
		END as p_medio
	   from t_simple_ordenado, parametros
),
-- Cuadrantes para cada una de las partes
cuadrantes_partes as (
	select parte, 'Norte' as ubicacion, ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [p_nw, p_ne, p_medio, p_nw])), ST_SRID(geom)) as cuadrante from vertices_bbox_partes
	union
	select parte, 'Este' as ubicacion, ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [p_medio, p_ne, p_se, p_medio])), ST_SRID(geom)) as cuadrante from vertices_bbox_partes
	union
	select parte, 'Sur' as ubicacion, ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [p_medio, p_se, p_sw, p_medio])), ST_SRID(geom)) as cuadrante from vertices_bbox_partes
	union
	select parte, 'Oeste' as ubicacion, ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [p_nw, p_medio, p_sw, p_nw])), ST_SRID(geom)) as cuadrante from vertices_bbox_partes
),
-- Se obtienen linderos asociados a los linderos se utilizan las tablas topologicas
linderos AS (
	SELECT lc_lindero.t_id, lc_lindero.geometria AS geom  FROM ladm_lev_cat_v1.lc_lindero JOIN ladm_lev_cat_v1.col_masccl ON col_masccl.ue_mas_lc_terreno = (SELECT terreno_t_id FROM parametros) AND lc_lindero.t_id = col_masccl.ccl_mas
),
-- Se obtienen los terrenos asociados a los linderos del terreno seleccionado (Terrenos vecinos)
terrenos_asociados_linderos AS (
	SELECT DISTINCT col_masccl.ue_mas_lc_terreno AS t_id_terreno, col_masccl.ccl_mas AS t_id_lindero FROM ladm_lev_cat_v1.col_masccl WHERE col_masccl.ccl_mas IN (SELECT t_id FROM linderos) AND col_masccl.ue_mas_lc_terreno != (SELECT terreno_t_id FROM parametros)
),
-- Puntos linderos asociados al terreno
puntos_lindero AS (
	SELECT distinct lc_puntolindero.t_id, lc_puntolindero.geometria AS geom FROM ladm_lev_cat_v1.lc_puntolindero JOIN ladm_lev_cat_v1.col_puntoccl ON col_puntoccl.ccl IN (SELECT t_id FROM linderos) AND lc_puntolindero.t_id = col_puntoccl.punto_lc_puntolindero
),
puntos_terrenos_simple AS (
	select distinct on (geom) geom, parte, orden, total
	from (
		select (ST_DumpPoints(geom)).geom geom, parte, (ST_DumpPoints(geom)).path[2] orden, ST_NPoints(geom) total from t_simple_ordenado order by geom, parte, orden
	) as puntos_terrenos_unicos
	order by geom, parte, orden
),
-- Criterios para seleccionar el punto a partir del cual empiza la enumeración de los terrenos
punto_inicial_por_lindero_con_punto_nw AS (
	select distinct on (parte) parte, dist, orden as punto_inicial, geom, 1 as criterio from (
		SELECT 	pts.geom, pts.parte, pts.orden, pts.total,
				st_distance(pts.geom, vbp.p_nw) AS dist
		FROM puntos_terrenos_simple as pts JOIN vertices_bbox_partes as vbp ON pts.parte = vbp.parte
		ORDER BY dist
	) punto_inicial_parte_nw order by parte, dist
),
punto_inicial_por_lindero_con_punto_ne AS (
	select distinct on (parte) parte, dist, orden as punto_inicial, geom, 2 as criterio from (
		SELECT 	pts.geom, pts.parte, pts.orden, pts.total,
				st_distance(pts.geom, vbp.p_ne) AS dist
		FROM puntos_terrenos_simple as pts JOIN vertices_bbox_partes as vbp ON pts.parte = vbp.parte
		ORDER BY dist
	) punto_inicial_parte_ne order by parte, dist
),
punto_inicial AS (
	SELECT *
	FROM (
		SELECT *
		FROM punto_inicial_por_lindero_con_punto_nw
		UNION SELECT * FROM punto_inicial_por_lindero_con_punto_ne
	) AS union_puntos_inicio
	WHERE criterio = (SELECT criterio_punto_inicial FROM parametros)
),
-- Preordenación de los puntos terreno
pre_puntos_terreno_ordenados as (
	select row_number() OVER (order by parte, reordenar) as id, geom, parte from (
		select puntos_terrenos_simple.*, punto_inicial, case when orden - punto_inicial >=0 then orden - punto_inicial +1 else total - punto_inicial  + orden end as reordenar
		from puntos_terrenos_simple join punto_inicial
		on puntos_terrenos_simple.parte = punto_inicial.parte
		order by puntos_terrenos_simple.parte, puntos_terrenos_simple.orden
	) as puntos_ordenados_inicio order by parte, reordenar
)
,
-- Se define el punto inicial y final para cada parte
punto_inicial_final_parte as (
	select parte, min(id) punto_inicial, max(id) punto_final from pre_puntos_terreno_ordenados group by parte
),
-- Puntos terrenos ordenados
puntos_terreno_ordenados as (
	select t1.*, t2.punto_inicial, punto_final from pre_puntos_terreno_ordenados as t1 join punto_inicial_final_parte as t2 on t1.parte = t2.parte
),
puntos_lindero_ordenados AS (
    SELECT * FROM (
        SELECT DISTINCT ON (t_id) t_id, id, st_distance(puntos_lindero.geom, puntos_terreno_ordenados.geom) AS distance, puntos_lindero.geom, round(st_x(puntos_lindero.geom)::numeric,3) x, round(st_y(puntos_lindero.geom)::numeric, 3) y, parte, punto_inicial, punto_final
        FROM puntos_lindero, puntos_terreno_ordenados ORDER BY t_id, distance
        LIMIT (SELECT count(t_id) FROM puntos_lindero)
    ) tmp_puntos_lindero_ordenados ORDER BY id
)
SELECT array_to_json(array_agg(features)) AS features
FROM (
	SELECT f AS features
	FROM (
		SELECT 'Feature' AS type
		,ST_AsGeoJSON(geom)::json AS geometry
		,row_to_json((
				SELECT l
				FROM (
					SELECT id AS point_number
					) AS l
				)) AS properties
	FROM puntos_lindero_ordenados order by id
	) AS f
) AS ff;