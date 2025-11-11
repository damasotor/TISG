DROP FUNCTION trace_route_approximate(integer,integer,integer)
-- ===========================================
-- FUNCIÓN CON ALGORITMO DE RUTA APROXIMADO - CON GUARDADO EN TABLA
-- ===========================================
CREATE OR REPLACE FUNCTION trace_route_approximate(
    start_stop_id INTEGER,
    end_stop_id INTEGER,
    max_segments INTEGER DEFAULT 50
)
RETURNS TABLE (
    segment_order INTEGER,
    gid INTEGER,
    nombre_calle TEXT,
    segment_geom geometry,
    distance_meters DOUBLE PRECISION
) AS $$
DECLARE
    start_point geometry;
    end_point geometry;
    current_point geometry;
    remaining_segments INTEGER;
    current_gid INTEGER;
    closest_gid INTEGER;
    found_geom geometry;
    current_nombre_calle TEXT;
    total_route_geometry geometry; -- Para almacenar la ruta completa
    segment_count INTEGER := 0;
    geom_collection geometry[] := '{}'; -- Array para coleccionar geometrías
BEGIN
    -- Obtener puntos de inicio y fin
    SELECT ST_SetSRID(ST_MakePoint(lon, lat), 4326)
    INTO start_point
    FROM public.paradas
    WHERE id = start_stop_id;

    SELECT ST_SetSRID(ST_MakePoint(lon, lat), 4326)
    INTO end_point
    FROM public.paradas
    WHERE id = end_stop_id;

    IF start_point IS NULL THEN
        RAISE EXCEPTION 'Parada de inicio (ID: %) no existe.', start_stop_id;
    END IF;

    IF end_point IS NULL THEN
        RAISE EXCEPTION 'Parada de destino (ID: %) no existe.', end_stop_id;
    END IF;

    current_point := start_point;
    remaining_segments := max_segments;
    segment_order := 0;

    WHILE remaining_segments > 0 AND ST_Distance(current_point::geography, end_point::geography) > 50 LOOP
        -- Encontrar la vía más cercana al punto actual
        SELECT v."GID", v.geom, v."NOM_CALLE"
        INTO closest_gid, found_geom, current_nombre_calle
        FROM public."v_sig_vias.shp" v
        WHERE v."GID" != COALESCE(current_gid, -1)
        ORDER BY ST_Distance(v.geom, current_point)
        LIMIT 1;

        IF closest_gid IS NULL THEN
            EXIT;
        END IF;

        -- Avanzar al punto más cercano al destino en esta vía
        current_point := ST_ClosestPoint(found_geom, end_point);
        current_gid := closest_gid;
        segment_order := segment_order + 1;
        remaining_segments := remaining_segments - 1;
        segment_count := segment_count + 1;

        -- Agregar geometría al array de colección
        geom_collection := array_append(geom_collection, found_geom);

        -- Devolver este segmento
        gid := closest_gid;
        nombre_calle := current_nombre_calle;
        segment_geom := found_geom;
        distance_meters := ST_Distance(found_geom::geography, current_point::geography);
        
        RETURN NEXT;
    END LOOP;

    -- Crear geometría de ruta completa combinando todos los segmentos
    IF array_length(geom_collection, 1) > 0 THEN
        -- Combinar todas las geometrías en una sola LineString
        SELECT ST_LineMerge(ST_Union(geom_collection)) INTO total_route_geometry;
        
        -- Insertar en la tabla de resultados
        INSERT INTO public.rutas_resultado (
            start_stop_id, 
            end_stop_id, 
            route_geom,
            created_at
        ) VALUES (
            start_stop_id,
            end_stop_id,
            total_route_geometry,
            NOW()
        );
    END IF;

END;
$$ LANGUAGE plpgsql;
-- Función con algoritmo aproximado
SELECT * FROM trace_route_approximate(1, 2, 20);
-- Ver las rutas guardadas
SELECT * FROM public.rutas_resultado;