-- ===========================================
-- Extensiones necesarias
-- ===========================================
CREATE EXTENSION IF NOT EXISTS postgis;
-- CREATE EXTENSION IF NOT EXISTS pgrouting;

-- ===========================================
-- TABLA DE RESULTADOS DE RUTAS
-- ===========================================
CREATE TABLE IF NOT EXISTS public.rutas_resultado (
    id SERIAL PRIMARY KEY,
    start_stop_cod INTEGER,
    end_stop_cod INTEGER,
    route_geom geometry(LineString, 4326),
    created_at TIMESTAMP DEFAULT now()
);

-- ===========================================
-- FUNCION AUXILIAR: encontrar nodo más cercano
-- ===========================================
CREATE OR REPLACE FUNCTION find_nearest_node(
    x DOUBLE PRECISION,
    y DOUBLE PRECISION,
    tol DOUBLE PRECISION
)
RETURNS INTEGER AS $$
DECLARE
    nearest_node INTEGER;
BEGIN
    SELECT "GID"
    INTO nearest_node
    FROM public."v_sig_vias.shp"
    ORDER BY ST_Distance(
        "geom",
        ST_SetSRID(ST_MakePoint(x, y), 4326)
    )
    LIMIT 1;

    RETURN nearest_node;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- FUNCION PRINCIPAL: trazar y guardar ruta
-- ===========================================
CREATE OR REPLACE FUNCTION trace_route_between_stops(
    start_stop_cod INTEGER,
    end_stop_cod INTEGER
)
RETURNS TABLE (
    seq INTEGER,
    gid INTEGER,
    geom geometry
) AS $$
DECLARE
    geom_start geometry;
    geom_end geometry;
    start_node INTEGER;
    end_node INTEGER;
    route_geom geometry;
BEGIN
    -- 1️⃣ Obtener geometrías de las paradas según COD_UBIC_P (con conversión)
    SELECT geometria INTO geom_start
	FROM public.v_uptu_paradas
	WHERE "COD_UBIC_P"::integer = start_stop_cod::integer;

    SELECT geometria INTO geom_end
    FROM public.v_uptu_paradas
    WHERE "COD_UBIC_P"::integer = end_stop_cod::integer;

    IF geom_start IS NULL OR geom_end IS NULL THEN
        RAISE EXCEPTION 'Una o ambas paradas no existen en v_uptu_paradas.';
    END IF;

    -- (el resto igual)
    start_node := find_nearest_node(ST_X(geom_start), ST_Y(geom_start), 0.0001);
    end_node := find_nearest_node(ST_X(geom_end), ST_Y(geom_end), 0.0001);

    RETURN QUERY
    SELECT
        route.seq::INTEGER AS seq,
        v."GID"::INTEGER AS gid,
        v."geom" AS geom
    FROM
        pgr_dijkstra(
            'SELECT "GID" AS id,
                    source,
                    target,
                    ST_Length("geom"::geography) AS cost
             FROM public."v_sig_vias.shp"',
            start_node,
            end_node,
            directed := false
        ) AS route
    JOIN
        public."v_sig_vias.shp" v
        ON route.edge = v."GID";

    SELECT ST_LineMerge(ST_Union(v."geom"))
    INTO route_geom
    FROM pgr_dijkstra(
            'SELECT "GID" AS id,
                    source,
                    target,
                    ST_Length("geom"::geography) AS cost
             FROM public."v_sig_vias.shp"',
            start_node,
            end_node,
            directed := false
        ) AS route
    JOIN
        public."v_sig_vias.shp" v
        ON route.edge = v."GID";

    IF route_geom IS NOT NULL THEN
        INSERT INTO public.rutas_resultado (start_stop_cod, end_stop_cod, route_geom)
        VALUES (start_stop_cod, end_stop_cod, route_geom);
    END IF;

END;
$$ LANGUAGE plpgsql;




SELECT * FROM trace_route_between_stops(4006, 3182);
SELECT EXISTS (
    SELECT 1
    FROM public.v_uptu_paradas
    WHERE "COD_UBIC_P"::integer = 4006
);
SELECT EXISTS (
    SELECT 1
    FROM public.v_uptu_paradas
    WHERE "COD_UBIC_P"::integer = 3182
);
SELECT "COD_UBIC_P", ST_AsText(geometria)
FROM public.v_uptu_paradas
WHERE "COD_UBIC_P" IN (4006, 3182);
DROP FUNCTION trace_route_between_stops(integer, integer);