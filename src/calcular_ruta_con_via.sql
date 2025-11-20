CREATE OR REPLACE FUNCTION public.calcular_ruta_con_via(
    id_inicio integer,
    via_lon double precision,
    via_lat double precision,
    id_fin integer
) RETURNS geometry
LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_node integer;
    v_via_node   integer;
    v_end_node   integer;
    v_geom_total geometry;
BEGIN
    -- 1) Nodos en la red más cercanos a inicio, via y fin
    SELECT id INTO v_start_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> (SELECT geom FROM public.paradas WHERE id = id_inicio)
    LIMIT 1;

    SELECT id INTO v_via_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> ST_SetSRID(ST_MakePoint(via_lon, via_lat), 4326)
    LIMIT 1;

    SELECT id INTO v_end_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> (SELECT geom FROM public.paradas WHERE id = id_fin)
    LIMIT 1;

    IF v_start_node IS NULL OR v_via_node IS NULL OR v_end_node IS NULL THEN
        RETURN NULL;
    END IF;

    WITH
    -- tramo inicio → via
    dijkstra_1 AS (
        SELECT r.seq, r.edge
        FROM pgr_dijkstra(
            'SELECT gid_int AS id,
                    source::integer AS source,
                    target::integer AS target,
                    ST_Length(geom::geography) AS cost
             FROM public.v_sig_vias',
            v_start_node,
            v_via_node,
            false
        ) AS r
        WHERE r.edge > 0
        ORDER BY r.seq
    ),
    ruta1 AS (
        SELECT v.geom
        FROM dijkstra_1 dr
        JOIN public.v_sig_vias v
          ON v.gid_int = dr.edge
    ),

    -- tramo via → fin
    dijkstra_2 AS (
        SELECT r.seq, r.edge
        FROM pgr_dijkstra(
            'SELECT gid_int AS id,
                    source::integer AS source,
                    target::integer AS target,
                    ST_Length(geom::geography) AS cost
             FROM public.v_sig_vias',
            v_via_node,
            v_end_node,
            false
        ) AS r
        WHERE r.edge > 0
        ORDER BY r.seq
    ),
    ruta2 AS (
        SELECT v.geom
        FROM dijkstra_2 dr
        JOIN public.v_sig_vias v
          ON v.gid_int = dr.edge
    )

    -- unir ambos tramos en orden
    SELECT ST_Multi(ST_LineMerge(ST_Collect(geom)))
    INTO v_geom_total
    FROM (
        SELECT geom FROM ruta1
        UNION ALL
        SELECT geom FROM ruta2
    ) AS sub;

    IF v_geom_total IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN v_geom_total;
END;
$function$;

