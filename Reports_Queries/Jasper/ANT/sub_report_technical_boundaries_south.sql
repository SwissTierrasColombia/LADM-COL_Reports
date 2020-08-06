WITH
parametros AS (
  SELECT
    1432 	AS terreno_t_id, --$P{id}
     1 		AS criterio_punto_inicial, --tipo de criterio para seleccionar el punto inicial del terreno, valores posibles: 1,2 parametrizar $P{criterio_punto_inicial}
     4		AS criterio_observador, --1: Centroide, 2: Centro del extent, 3: punto en la superficie, 4: Punto mas cercano al centroide dentro del poligono
	false	AS incluir_tipo_derecho, --Mostrar el tipo de derecho de cada interesado (booleano)
	15		AS tolerancia_sentidos --tolerancia en grados para la definicion del sentido de una linea
),
t AS (
	SELECT t_id, ST_ForceRHR(geometria) AS geometria FROM ladm_lev_cat_v1.lc_terreno WHERE t_id = (SELECT terreno_t_id FROM parametros)
),
linderos AS (
	SELECT lc_lindero.t_id, lc_lindero.geometria AS geom  FROM ladm_lev_cat_v1.lc_lindero JOIN ladm_lev_cat_v1.col_masccl ON col_masccl.ue_mas_lc_terreno = (SELECT terreno_t_id FROM parametros) AND lc_lindero.t_id = col_masccl.ccl_mas
),
terrenos_asociados_linderos AS (
	SELECT DISTINCT col_masccl.ue_mas_lc_terreno AS t_id_terreno, col_masccl.ccl_mas AS t_id_lindero FROM ladm_lev_cat_v1.col_masccl WHERE col_masccl.ccl_mas IN (SELECT t_id FROM linderos) AND col_masccl.ue_mas_lc_terreno != (SELECT terreno_t_id FROM parametros)
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
punto_se AS (
	SELECT ST_SetSRID(ST_MakePoint(st_xmax(t.geometria), st_ymin(t.geometria)), ST_SRID(t.geometria)) AS p FROM t
),
punto_sw AS (
	SELECT ST_SetSRID(ST_MakePoint(st_xmin(t.geometria), st_ymin(t.geometria)), ST_SRID(t.geometria)) AS p FROM t
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
cuadrante_este AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [punto_medio.p, punto_ne.p, punto_se.p, punto_medio.p])), ST_SRID(t.geometria)) geom FROM t,punto_ne,punto_se,punto_medio
),
cuadrante_sur AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [punto_medio.p, punto_se.p, punto_sw.p, punto_medio.p])), ST_SRID(t.geometria)) geom FROM t,punto_medio,punto_se,punto_sw
),
cuadrante_oeste AS (
	SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY [punto_nw.p, punto_medio.p, punto_sw.p, punto_nw.p])), ST_SRID(t.geometria)) geom FROM t,punto_nw,punto_medio,punto_sw
),
cuadrantes AS (
	SELECT '1_Norte' ubicacion, geom AS cuadrante FROM cuadrante_norte
	UNION
	SELECT '2_Este' ubicacion, geom AS cuadrante FROM cuadrante_este
	UNION
	SELECT '3_Sur' ubicacion, geom AS cuadrante FROM cuadrante_sur
	UNION
	SELECT '4_Oeste' ubicacion, geom AS cuadrante FROM cuadrante_oeste
),
punto_inicial_por_lindero_porcentaje_n AS (
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
),
linderos_desde_hasta AS (
	SELECT *
		, (SELECT id FROM (
			SELECT id, st_distance(puntos_lindero_ordenados.geom, st_startpoint(linderos.geom)) AS distance FROM puntos_lindero_ordenados ORDER BY distance ASC LIMIT 1
		) AS tmp_desde) desde
		, (SELECT id FROM (
			SELECT id, st_distance(puntos_lindero_ordenados.geom, st_endpoint(linderos.geom)) AS distance FROM puntos_lindero_ordenados ORDER BY distance ASC LIMIT 1
		) AS tmp_hasta) hasta
	FROM linderos
	ORDER BY desde
),
linderos_colindantes AS (
	SELECT row_number() OVER (ORDER BY desde) AS id, t_id AS t_id_linderos, desde, hasta, ubicacion, geom FROM
	(
		SELECT *
			,st_length(st_intersection(geom,cuadrante))/st_length(geom) AS porcentaje
			,max(st_length(st_intersection(geom,cuadrante))/st_length(geom)) OVER (partition BY geom) AS max_porce
		FROM linderos_desde_hasta, cuadrantes WHERE st_intersects(geom,  cuadrante)
	) a
	WHERE porcentaje = max_porce
),
colindantes AS (
	SELECT linderos_colindantes.*, terrenos_asociados_linderos.t_id_terreno  FROM linderos_colindantes JOIN terrenos_asociados_linderos ON linderos_colindantes.t_id_linderos = terrenos_asociados_linderos.t_id_lindero
),
predios_seleccionados AS (
	SELECT baunit AS t_id_predio, colindantes.t_id_terreno AS t_id_colindante FROM colindantes
	LEFT JOIN ladm_lev_cat_v1.col_uebaunit ON colindantes.t_id_terreno = ue_lc_terreno
),
derechos_seleccionados AS (
	 SELECT DISTINCT lc_derecho.t_id AS t_id_derecho, predios_seleccionados.t_id_colindante
	 FROM predios_seleccionados LEFT JOIN ladm_lev_cat_v1.lc_derecho
	 ON lc_derecho.unidad = predios_seleccionados.t_id_predio
 ),
 derecho_interesados AS (
	 SELECT DISTINCT lc_derecho.interesado_lc_interesado, lc_derecho.t_id AS t_id_derecho, derechos_seleccionados.t_id_colindante
	 FROM derechos_seleccionados LEFT JOIN ladm_lev_cat_v1.lc_derecho
	 ON lc_derecho.t_id = derechos_seleccionados.t_id_derecho WHERE lc_derecho.interesado_lc_interesado IS NOT NULL
 ),
 derecho_agrupacion_interesados AS (
	 SELECT DISTINCT lc_derecho.interesado_lc_agrupacioninteresados, col_miembros.interesado_lc_interesado, derechos_seleccionados.t_id_colindante, col_miembros.agrupacion
	 FROM derechos_seleccionados LEFT JOIN ladm_lev_cat_v1.lc_derecho
	 ON lc_derecho.t_id = derechos_seleccionados.t_id_derecho
	 LEFT JOIN ladm_lev_cat_v1.col_miembros
	 ON lc_derecho.interesado_lc_agrupacioninteresados = col_miembros.agrupacion
	 WHERE lc_derecho.interesado_lc_agrupacioninteresados IS NOT NULL
 ),
 info_agrupacion_filter AS (
		SELECT DISTINCT ON (agrupacion) agrupacion
		,lc_interesado.local_id AS local_id
		,(CASE WHEN lc_interesado.t_id IS NOT null THEN 'agrupacion' END) AS agrupacion_interesado
	 	,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '')
				|| coalesce(lc_interesado.razon_social, '') ) AS nombre
		,t_id_colindante
		FROM derecho_agrupacion_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_agrupacion_interesados.interesado_lc_interesado order BY agrupacion
 ),
 info_interesado AS (
		SELECT
	 	lc_interesado.local_id AS local_id
	 	,(CASE WHEN lc_interesado.t_id IS NOT null THEN 'interesado' END) AS agrupacion_interesado
	 	,(coalesce(lc_interesado.primer_nombre,'') || coalesce(' ' || lc_interesado.segundo_nombre, '') || coalesce(' ' || lc_interesado.primer_apellido, '') || coalesce(' ' || lc_interesado.segundo_apellido, '')
				|| coalesce(lc_interesado.razon_social, '') ) AS nombre
		,t_id_colindante
 		FROM derecho_interesados LEFT JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = derecho_interesados.interesado_lc_interesado
 ),
 info_agrupacion AS (
		SELECT local_id
		,agrupacion_interesado
		,nombre
		,t_id_colindante
		FROM info_agrupacion_filter
),
 info_total_interesados AS (SELECT * FROM info_interesado UNION all SELECT * FROM info_agrupacion)
 SELECT
   id
  ,desde
  ,hasta
  ,ubicacion
  ,round(st_x(st_startpoint(colindantes.geom))::numeric,2) xi
  ,round(st_y(st_startpoint(colindantes.geom))::numeric,2) yi
  ,round(st_x(st_endpoint(colindantes.geom))::numeric,2) xf
  ,round(st_y(st_endpoint(colindantes.geom))::numeric,2) yf
  ,COALESCE(info_total_interesados.nombre, 'INDETERMINADO') AS interesado
  ,COALESCE(info_total_interesados.agrupacion_interesado, 'INDETERMINADO') AS tipo_interesado
  ,round(st_length(colindantes.geom)::numeric,2) distancia
  ,(SELECT array_to_string( array_agg(puntos_lindero_ordenados.id || ': N=' || round(st_y(puntos_lindero_ordenados.geom)::numeric,2) || ' metros (m.), E=' || round(st_x(puntos_lindero_ordenados.geom)::numeric,2) || ' metros (m.)'), '; ') FROM puntos_lindero_ordenados WHERE st_intersects(colindantes.geom,puntos_lindero_ordenados.geom) and puntos_lindero_ordenados.id NOT IN (desde, hasta) ) AS nodos
  ,degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2)))
  ,CASE WHEN degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2))) BETWEEN 360-(SELECT tolerancia_sentidos FROM parametros) and 360 or degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2))) BETWEEN 0 and (SELECT tolerancia_sentidos FROM parametros) THEN 'norte'
	  WHEN degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2))) BETWEEN (SELECT tolerancia_sentidos FROM parametros) and 90-(SELECT tolerancia_sentidos FROM parametros) THEN 'noreste'
	  WHEN degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2))) BETWEEN 90-(SELECT tolerancia_sentidos FROM parametros) and 90+(SELECT tolerancia_sentidos FROM parametros) THEN 'este'
	  WHEN degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2))) BETWEEN 90+(SELECT tolerancia_sentidos FROM parametros) and 180-(SELECT tolerancia_sentidos FROM parametros) THEN 'sureste'
	  WHEN degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2))) BETWEEN 180-(SELECT tolerancia_sentidos FROM parametros) and 180+(SELECT tolerancia_sentidos FROM parametros) THEN 'sur'
	  WHEN degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2))) BETWEEN 180+(SELECT tolerancia_sentidos FROM parametros) and 270-(SELECT tolerancia_sentidos FROM parametros) THEN 'suroeste'
	  WHEN degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2))) BETWEEN 270-(SELECT tolerancia_sentidos FROM parametros) and 270+(SELECT tolerancia_sentidos FROM parametros) THEN 'oeste'
	  WHEN degrees(ST_Azimuth(st_startpoint(geom),ST_PointN(geom,2))) BETWEEN 270+(SELECT tolerancia_sentidos FROM parametros) and 360-(SELECT tolerancia_sentidos FROM parametros) THEN 'noroeste'
  END AS sentido
  ,(SELECT count(*) FROM colindantes) AS total_linderos
 FROM colindantes LEFT JOIN info_total_interesados ON colindantes.t_id_terreno = info_total_interesados.t_id_colindante
 WHERE ubicacion = '3_Sur'