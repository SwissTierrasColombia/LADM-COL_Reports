WITH
parametros AS (
  SELECT
    1432 	AS terreno_t_id, --$P{id}
     2 		AS criterio_punto_inicial, --tipo de criterio para seleccionar el punto inicial del terreno, valores posibles: 1,2 parametrizar $P{criterio_punto_inicial}
     4		AS criterio_observador --1: Centroide, 2: Centro del extent, 3: punto en la superficie, 4: Punto mas cercano al centroide dentro del poligono
),
t AS (
	SELECT t_id, ST_ForceRHR(geometria) AS geometria FROM ladm_lev_cat_v1.lc_terreno WHERE t_id = (SELECT terreno_t_id FROM parametros)
),
linderos AS (
	SELECT lc_lindero.t_id, lc_lindero.geometria AS geom  FROM ladm_lev_cat_v1.lc_lindero JOIN ladm_lev_cat_v1.col_masccl ON col_masccl.ue_mas_lc_terreno = (SELECT terreno_t_id FROM parametros) AND lc_lindero.t_id = col_masccl.ccl_mas
),
puntos_lindero AS (
	SELECT lc_puntolindero.t_id, lc_puntolindero.geometria AS geom FROM ladm_lev_cat_v1.lc_puntolindero JOIN ladm_lev_cat_v1.col_puntoccl ON col_puntoccl.ccl IN (SELECT t_id FROM linderos) AND lc_puntolindero.t_id = col_puntoccl.punto_lc_puntolindero
),
puntos_terreno AS (
	SELECT (ST_DumpPoints(geometria)).* AS dp,
			ST_NPoints(geometria) total
	FROM t
),
--bordes de la extension del poligono
punto_nw AS (
	SELECT ST_SetSRID(ST_MakePoint(st_xmin(t.geometria), st_ymax(t.geometria)), ST_SRID(t.geometria)) AS p FROM t
),
punto_ne AS (
	SELECT ST_SetSRID(ST_MakePoint(st_xmax(t.geometria), st_ymax(t.geometria)), ST_SRID(t.geometria)) AS p FROM t
),
--Punto medio (ubicación del observador para la definicion de las cardinalidades)
punto_medio AS (
  SELECT
    CASE WHEN criterio_observador = 1 THEN --centroide del poligono
      ( SELECT ST_SetSRID(ST_MakePoint(st_x(ST_centroid(t.geometria)), st_y(ST_centroid(t.geometria))), ST_SRID(t.geometria)) AS p FROM t )
    WHEN criterio_observador = 2 THEN --Centro del extent
      ( SELECT ST_SetSRID(ST_MakePoint(st_x(ST_centroid(st_envelope(t.geometria))), st_y(ST_centroid(st_envelope(t.geometria)))), ST_SRID(t.geometria)) AS p FROM t )
    WHEN criterio_observador = 3 THEN --Punto en la superficie
      ( SELECT ST_SetSRID(ST_PointOnSurface(geometria), ST_SRID(t.geometria)) AS p FROM t )
    WHEN criterio_observador = 4 THEN --Punto mas cercano al centroide pero que se intersecte el poligono si esta fuera
      ( SELECT ST_SetSRID(ST_MakePoint(st_x( ST_ClosestPoint( geometria, ST_centroid(t.geometria))), st_y( ST_ClosestPoint( geometria,ST_centroid(t.geometria)))), ST_SRID(t.geometria)) AS p FROM t )
    ELSE --defecto: Centro del extent
      ( SELECT ST_SetSRID(ST_MakePoint(st_x(ST_centroid(st_envelope(t.geometria))), st_y(ST_centroid(st_envelope(t.geometria)))), ST_SRID(t.geometria)) AS p FROM t )
    END AS p
    FROM parametros
),
cuadrante_norte AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [punto_nw.p, punto_ne.p, punto_medio.p, punto_nw.p])), ST_SRID(t.geometria)) geom FROM t, punto_nw, punto_ne, punto_medio
),
punto_inicial_por_lindero_porcentaje_n AS(
	SELECT 	round((st_length(st_intersection(linderos.geom, cuadrante_norte.geom))/st_length(linderos.geom))::numeric,2) dist,
		st_startpoint(linderos.geom) geom
		,st_distance(linderos.geom, punto_nw.p) distance_to_nw
		FROM linderos
			,cuadrante_norte
			, punto_nw
		WHERE st_intersects(linderos.geom, cuadrante_norte.geom)  ORDER BY dist DESC, distance_to_nw
		LIMIT 1
),
punto_inicial_por_lindero_con_punto_nw AS (
	SELECT 	geom,
			st_distance(geom, nw) AS dist
	FROM puntos_terreno,
		(SELECT ST_SetSRID(ST_MakePoint(st_xmin(st_envelope(geometria)), st_ymax(st_envelope(geometria))), ST_SRID(geometria)) AS nw FROM t) a
	ORDER BY dist LIMIT 1
),
punto_inicial AS (
	SELECT
		CASE WHEN criterio_punto_inicial = 1 THEN (SELECT geom FROM punto_inicial_por_lindero_con_punto_nw)
		WHEN criterio_punto_inicial = 2 THEN (SELECT geom FROM punto_inicial_por_lindero_porcentaje_n)
	END AS geom
	FROM parametros
),
puntos_terreno_ordenados AS (
	SELECT CASE WHEN id-m+1 <= 0 THEN total + id-m ELSE id-m+1 END AS id, geom  FROM
		(
		SELECT row_number() OVER (ORDER BY path) AS id
			,m
			,path
			,geom
			,total
		FROM (
			SELECT (ST_DumpPoints(geometria)).* AS dp
				,ST_NPoints(geometria) total
				,geometria
			FROM t
			) AS a
			,(
				SELECT row_number() OVER (ORDER BY path) AS m
					,st_distance(puntos_terreno.geom, punto_inicial.geom) AS dist
				FROM puntos_terreno,punto_inicial
				ORDER BY dist LIMIT 1
			) b
		) t
		WHERE id <> total
	ORDER BY id
),
puntos_lindero_ordenados AS (
    SELECT * FROM (
        SELECT DISTINCT ON (t_id) t_id, id, st_distance(puntos_lindero.geom, puntos_terreno_ordenados.geom) AS distance, puntos_lindero.geom, st_x(puntos_lindero.geom) x, st_y(puntos_lindero.geom) y
        FROM puntos_lindero, puntos_terreno_ordenados ORDER BY t_id, distance
        LIMIT (SELECT count(DISTINCT t_id) FROM puntos_lindero)
    ) tmp_puntos_lindero_ordenados ORDER BY id
)
SELECT * FROM
(
	SELECT c1.id AS "from", c2.id AS "to", c1.x, c1.y, st_distance(c1.geom,c2.geom) AS dist FROM puntos_lindero_ordenados c1, puntos_lindero_ordenados c2 WHERE c1.id +1  = c2.id
	UNION
	SELECT c1.id AS "from", c2.id AS "to", c1.x, c1.y, st_distance(c1.geom,c2.geom) AS dist FROM (SELECT * FROM puntos_lindero_ordenados ORDER BY id DESC LIMIT 1) c1, (SELECT * FROM puntos_lindero_ordenados ORDER BY id ASC LIMIT 1) c2
) t ORDER BY "from"