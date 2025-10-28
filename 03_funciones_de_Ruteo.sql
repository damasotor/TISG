-- ===============================================
-- 0. CREACIÓN DE TOPOLOGÍA (ESENCIAL PARA pgr_dijkstra)
-- ===============================================
-- Antes de calcular rutas, pgRouting necesita que la red vial
-- tenga nodos (vértices) bien definidos.

-- CORRECCIÓN CRÍTICA:
-- 1. Tabla corregida a 'v_sig_vias' (sin .shp ni comillas dobles).
-- 2. Columna de geometría corregida a 'geometria' (como está en 02_carga_datos.sql).
-- 3. Columna de ID corregida a 'gid'.
SELECT pgr_createTopology('v_sig_vias', 0.0001, 'geometria', 'gid', true);


-- ===============================================
-- 1. FUNCIÓN DE RUTEADOR (DIJKSTRA)
-- ===============================================
CREATE OR REPLACE FUNCTION pgr_findRoute(
    start_lon float, start_lat float,
    end_lon float, end_lat float
)
RETURNS TABLE (
    seq integer,
    cost numeric,
    geom geometry
) AS $$
DECLARE
    start_point geometry;
    end_point geometry;
    source_vertex bigint;
    target_vertex bigint;
    -- Se define el nombre correcto de la tabla de vértices generada por pgr_createTopology
    vertex_table_name constant text := 'v_sig_vias_vertices_pgr';
BEGIN
    -- 1. Crear geometrías a partir de las coordenadas de entrada (SRID 4326)
    start_point := ST_SetSRID(ST_MakePoint(start_lon, start_lat), 4326);
    end_point := ST_SetSRID(ST_MakePoint(end_lon, end_lat), 4326);

    -- 2. Encontrar el nodo más cercano (vértice de la red vial) al punto de inicio/fin
    -- Se usa la tabla de vértices generada automáticamente (v_sig_vias_vertices_pgr)
    EXECUTE format(
        'SELECT id FROM %I ORDER BY the_geom <-> $1 LIMIT 1', vertex_table_name
    ) INTO source_vertex USING start_point;

    EXECUTE format(
        'SELECT id FROM %I ORDER BY the_geom <-> $1 LIMIT 1', vertex_table_name
    ) INTO target_vertex USING end_point;

    -- Si no se encuentra el source o target, salir
    IF source_vertex IS NULL OR target_vertex IS NULL THEN
        RAISE EXCEPTION 'No se encontraron nodos de red vial cercanos para las coordenadas provistas.';
    END IF;

    -- 3. Calcular la ruta con pgr_dijkstra
    -- Se incluye 'longitud' como reverse_cost para rutas bi-direccionales.
    RETURN QUERY
    SELECT
        (route.seq)::integer as seq,
        route.cost::numeric,
        agg.geometria -- CORRECCIÓN: Se usa la columna 'geometria'
    FROM pgr_dijkstra(
        'SELECT gid AS id, source, target, cost, longitud AS reverse_cost, ST_AsEWKT(geometria) AS geom FROM v_sig_vias',
        source_vertex,
        target_vertex,
        directed := false -- Se asume red no dirigida
    ) as route
    JOIN v_sig_vias as agg -- Unir el resultado de la ruta con la tabla de vías
    ON route.edge = agg.gid
    ORDER BY route.seq;

END;
$$ LANGUAGE plpgsql;
