WITH
parametros AS (
  SELECT
    1432 	AS terreno_t_id, --$P{id}
     2 		AS criterio_punto_inicial, --tipo de criterio para seleccionar el punto inicial del terreno, valores posibles: 1,2 parametrizar $P{criterio_punto_inicial}
     4		AS criterio_observador, --1: Centroide, 2: Centro del extent, 3: punto en la superficie, 4: Punto mas cercano al centroide dentro del poligono
	true	AS incluir_tipo_derecho --Mostrar el tipo de derecho de cada interesado (booleano)
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
	SELECT 'Norte' ubicacion, geom AS cuadrante FROM cuadrante_norte
	UNION
	SELECT 'Este' ubicacion, geom AS cuadrante FROM cuadrante_este
	UNION
	SELECT 'Sur' ubicacion, geom AS cuadrante FROM cuadrante_sur
	UNION
	SELECT 'Oeste' ubicacion, geom AS cuadrante FROM cuadrante_oeste
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
)
SELECT
  id
  ,desde
  ,hasta
  ,ubicacion
  ,nupre
  ,CASE WHEN numero_predial is null AND matricula_inmobiliaria IS NULL AND nombre IS NULL THEN 'ÁREA INDETERMINADA'
    ELSE COALESCE(numero_predial || ';','') || COALESCE('FMI: ' || matricula_inmobiliaria || ';','') || COALESCE('Nombre: ' || nombre ,'')
   END AS predio
  ,lc_predio.t_id
  ,COALESCE(interesado, 'INDETERMINADO') AS interesado
  ,round(st_length(colindantes.geom)::numeric,2) distancia
FROM
colindantes
LEFT JOIN ladm_lev_cat_v1.lc_terreno ON lc_terreno.t_id = colindantes.t_id_terreno --$P!{datasetName}
LEFT JOIN ladm_lev_cat_v1.col_uebaunit ON colindantes.t_id_terreno = ue_lc_terreno --$P!{datasetName}
LEFT JOIN ladm_lev_cat_v1.lc_predio ON lc_predio.t_id = baunit --$P!{datasetName}
LEFT JOIN
(
  SELECT t_id,
	array_to_string(array_agg(( coalesce(primer_nombre,'') || coalesce(' ' || segundo_nombre, '') || coalesce(' ' || primer_apellido, '') || coalesce(' ' || segundo_apellido, '') )
				|| ( coalesce(razon_social, '') )
				|| ', ' || (SELECT dispname FROM ladm_lev_cat_v1.lc_interesadodocumentotipo WHERE t_id = tipo_documento) || ': ' --$P!{datasetName}
				|| documento_identidad
				|| CASE WHEN (SELECT incluir_tipo_derecho FROM parametros) THEN
					' (' || (SELECT dispname FROM ladm_lev_cat_v1.lc_derechotipo WHERE t_id = tipo_derecho) || ')' --opcional: ver tipo de derecho de cada interesado $P!{datasetName}
				  ELSE '' END
				) , '; ')
			  AS interesado
  FROM
  (
	--navegar agrupación de interesados
	SELECT * FROM
		ladm_lev_cat_v1.lc_predio -- $P!{datasetName}
		LEFT JOIN
		(
			SELECT
			  primer_nombre
			  ,segundo_nombre
			  ,primer_apellido
			  ,segundo_apellido
			  ,razon_social
			  ,tipo_documento
			  ,documento_identidad
			  ,unidad
			  ,lc_derecho.tipo AS tipo_derecho
			FROM
			  ladm_lev_cat_v1.lc_derecho --$P!{datasetName}
			  JOIN ladm_lev_cat_v1.lc_agrupacioninteresados ON lc_agrupacioninteresados.t_id = interesado_lc_agrupacioninteresados --$P!{datasetName}
			  JOIN ladm_lev_cat_v1.col_miembros ON agrupacion = lc_agrupacioninteresados.t_id --$P!{datasetName}
			  JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id = col_miembros.interesado_lc_interesado --$P!{datasetName}
		 ) agrupacion  ON lc_predio.t_id = agrupacion.unidad
	UNION
	--navegar agrupación de interesados
	SELECT * FROM
		ladm_lev_cat_v1.lc_predio --$P!{datasetName}
		LEFT JOIN
		(
			SELECT
			  primer_nombre
			  ,segundo_nombre
			  ,primer_apellido
			  ,segundo_apellido
			  ,razon_social
			  ,tipo_documento
			  ,documento_identidad
			  ,unidad
			  ,lc_derecho.tipo AS tipo_derecho
			FROM
			  ladm_lev_cat_v1.lc_derecho --$P!{datasetName}
			  JOIN ladm_lev_cat_v1.lc_interesado ON lc_interesado.t_id =interesado_lc_interesado --$P!{datasetName}
		) interesado ON lc_predio.t_id = interesado.unidad
  ) interesados
  group BY t_id
) interesados ON interesados.t_id = lc_predio.t_id
ORDER BY id