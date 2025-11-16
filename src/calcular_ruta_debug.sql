DROP FUNCTION IF EXISTS calcular_ruta_debug(integer, integer);

CREATE OR REPLACE FUNCTION calcular_ruta_debug(
    p_inicio integer,
    p_fin integer
)
RETURNS TABLE (
    start_stop_id integer,
    end_stop_id integer,
    nodo_inicio bigint,
    nodo_fin bigint,
    dist_p_ini_m double precision, -- Distancia de la parada al nodo inicial (en metros)
    dist_p_fin_m double precision  -- Distancia de la parada al nodo final (en metros)
)
LANGUAGE plpgsql
AS $func$ -- Cambiamos el tag de $$, para evitar posibles conflictos o parsing erróneo
BEGIN
    RETURN QUERY
    WITH
    -- Nodo inicial más cercano a la parada de inicio
    p_ini_calc AS (
        SELECT v.id AS nodo,
               ST_Distance(
                  ST_Transform(p.geom,4326)::geography,
                  ST_Transform(v.the_geom,4326)::geography
              ) AS distance_m
        FROM public.paradas p
        JOIN public.v_sig_vias_vertices_pgr v
          ON ST_DWithin(
               ST_Transform(p.geom,4326)::geography,
               ST_Transform(v.the_geom,4326)::geography,
               500.0 -- Rango de búsqueda: 500 metros
             )
        WHERE p.id = p_inicio
        ORDER BY distance_m
        LIMIT 1
    ),
    -- Nodo final más cercano a la parada destino
    p_fin_calc AS (
        SELECT v.id AS nodo,
               ST_Distance(
                  ST_Transform(p.geom,4326)::geography,
                  ST_Transform(v.the_geom,4326)::geography
              ) AS distance_m
        FROM public.paradas p
        JOIN public.v_sig_vias_vertices_pgr v
          ON ST_DWithin(
               ST_Transform(p.geom,4326)::geography,
               ST_Transform(v.the_geom,4326)::geography,
               500.0 -- Rango de búsqueda: 500 metros
             )
        WHERE p.id = p_fin
        ORDER BY distance_m
        LIMIT 1
    )
    SELECT
        p_inicio AS start_stop_id,
        p_fin AS end_stop_id,
        (SELECT nodo FROM p_ini_calc) AS nodo_inicio,
        (SELECT nodo FROM p_fin_calc) AS nodo_fin,
        (SELECT distance_m FROM p_ini_calc) AS dist_p_ini_m,
        (SELECT distance_m FROM p_fin_calc) AS dist_p_fin_m;
END;
$func$; -- Se cierra con el mismo tag que se abrió
