-- DROP FUNCTION IF EXISTS calcular_ruta_debug(integer, integer);

CREATE OR REPLACE FUNCTION calcular_ruta_debug(
    p_inicio integer,
    p_fin integer
)
RETURNS TABLE (
    start_stop_id integer,
    end_stop_id integer,
    nodo_inicio bigint,
    nodo_fin bigint,
    edge bigint,
    geom_edge geometry,
    total_distance double precision
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH
    -- Nodo inicial más cercano a la parada de inicio
    p_ini AS (
        SELECT v.id AS nodo
        FROM public.paradas p
        JOIN public.v_sig_vias_vertices_pgr v
          ON ST_DWithin(
               ST_Transform(p.geom,4326)::geography,
               ST_Transform(v.geom,4326)::geography,
               500
             )
        WHERE p.id = p_inicio
        ORDER BY ST_Distance(
                  ST_Transform(p.geom,4326)::geography,
                  ST_Transform(v.geom,4326)::geography
              )
        LIMIT 1
    ),
    -- Nodo final más cercano a la parada destino
    p_fin_nodo AS (
        SELECT v.id AS nodo
        FROM public.paradas p
        JOIN public.v_sig_vias_vertices_pgr v
          ON ST_DWithin(
               ST_Transform(p.geom,4326)::geography,
               ST_Transform(v.geom,4326)::geography,
               500
             )
        WHERE p.id = p_fin
        ORDER BY ST_Distance(
                  ST_Transform(p.geom,4326)::geography,
                  ST_Transform(v.geom,4326)::geography
              )
        LIMIT 1
    ),
    -- Cálculo de la ruta con pgRouting usando la tabla de vías
    ruta AS (
        SELECT r.seq,
               r.path_seq,
               r.node::bigint AS node,
               r.edge::bigint AS edge,
               r.cost,
               r.agg_cost,
               v.geom
        FROM pgr_dijkstra(
            $_$
            SELECT "GID"::bigint AS id,
                   source::bigint AS source,
                   target::bigint AS target,
                   ST_Length(ST_Transform(geom,3857)) AS cost
            FROM public.v_sig_vias
            $_$,
            ARRAY[(SELECT nodo FROM p_ini)],
            ARRAY[(SELECT nodo FROM p_fin_nodo)]
        ) r
        LEFT JOIN public.v_sig_vias v ON r.edge = v."GID"
    ),
    -- Construcción de la geometría total y distancia
    geom_ruta AS (
        SELECT
            ST_LineMerge(ST_Union(geom)) AS geom_total,
            SUM(ST_Length(ST_Transform(geom,3857))) AS distancia_metros
        FROM ruta
        WHERE ruta.edge IS NOT NULL AND ruta.edge <> -1
    )
    SELECT
        p_inicio AS start_stop_id,
        p_fin AS end_stop_id,
        (SELECT nodo FROM p_ini) AS nodo_inicio,
        (SELECT nodo FROM p_fin_nodo) AS nodo_fin,
        r.edge,
        r.geom AS geom_edge,
        (SELECT distancia_metros FROM geom_ruta) AS total_distance
    FROM ruta r;
END;
$$;
