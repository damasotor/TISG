-- ===============================================
-- 0. CREACIÓN DE TOPOLOGÍA (ESENCIAL PARA pgr_dijkstra)
-- ===============================================
-- Este paso debe ejecutarse DESPUÉS de que las tablas estén cargadas.
-- 'v_sig_vias' es la tabla de vías.
-- 'geometria' es la columna de geometría.
-- 'gid' es la columna de ID única.
-- El valor 'true' al final fuerza la creación de las columnas source y target si no existen (aunque 02_carga_datos ya las crea).
SELECT pgr_createTopology('v_sig_vias', 0.0001, 'geometria', 'gid', true);


-- ===============================================
-- 1. FUNCIÓN DE RUTEADOR (DIJKSTRA)
-- ===============================================
-- Esta es la función principal que usa la topología recién creada.
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
        directed := false -- Se asume que la red es bidireccional
    ) AS route
    JOIN v_sig_vias AS agg ON route.edge = agg.gid
    ORDER BY route.seq;
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- 2. FUNCIÓN DE RUTEADOR (DIJKSTRA) V2 - CON PARADAS DE TRANSPORTE
-- ===============================================
-- Esta función encuentra la parada más cercana a las coordenadas y luego rutea entre esas paradas.
CREATE OR REPLACE FUNCTION pgr_findRoute_by_stops(
    start_lon float, start_lat float,
    end_lon float, end_lat float
)
RETURNS TABLE (
    seq integer,
    cost numeric,
    geom geometry
) AS $$
DECLARE
    start_stop_id integer;
    end_stop_id integer;
    start_stop_geom geometry;
    end_stop_geom geometry;
BEGIN
    -- 1. Encontrar la parada de transporte (v_uptu_paradas) más cercana al punto de inicio
    SELECT
        cod_ubic_p, geometria INTO start_stop_id, start_stop_geom
    FROM v_uptu_paradas
    ORDER BY geometria <-> ST_SetSRID(ST_MakePoint(start_lon, start_lat), 4326)
    LIMIT 1;

    -- 2. Encontrar la parada de transporte (v_uptu_paradas) más cercana al punto de fin
    SELECT
        cod_ubic_p, geometria INTO end_stop_id, end_stop_geom
    FROM v_uptu_paradas
    ORDER BY geometria <-> ST_SetSRID(ST_MakePoint(end_lon, end_lat), 4326)
    LIMIT 1;

    -- 3. Si se encuentran ambas paradas, llamar a la función de ruteo principal
    IF start_stop_id IS NOT NULL AND end_stop_id IS NOT NULL THEN
        -- Reutilizar pgr_findRoute, pero pasando las coordenadas de las paradas encontradas.
        -- Esto asegura que el ruteo inicie y termine en la red vial.
        RETURN QUERY SELECT * FROM pgr_findRoute(
            ST_X(start_stop_geom), ST_Y(start_stop_geom),
            ST_X(end_stop_geom), ST_Y(end_stop_geom)
        );
    ELSE
        RAISE EXCEPTION 'No se pudieron encontrar las paradas cercanas para el ruteo.';
    END IF;
END;
$$ LANGUAGE plpgsql;

