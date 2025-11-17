-- BACKUP (opcional)
-- CREATE FUNCTION public.calcular_ruta_backup(inicio integer, fin integer) RETURNS geometry AS $$ ... $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.calcular_ruta(inicio integer, fin integer)
 RETURNS geometry
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_geom_total geometry;
    v_start_node integer;
    v_end_node integer;
BEGIN
    -- Si inicio = fin devolvemos NULL (o podrías devolver punto vacío)
    IF inicio = fin THEN
        RETURN NULL;
    END IF;

    -- 1) Encontrar el vértice PGR más cercano a la parada inicio
    SELECT id INTO v_start_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> (SELECT geom FROM public.paradas WHERE id = inicio)
    LIMIT 1;

    -- 2) Encontrar el vértice PGR más cercano a la parada fin
    SELECT id INTO v_end_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> (SELECT geom FROM public.paradas WHERE id = fin)
    LIMIT 1;

    -- Si no se encontraron nodos, devolvemos NULL
    IF v_start_node IS NULL OR v_end_node IS NULL THEN
        RETURN NULL;
    END IF;

    -- 3) Ejecutar pgr_dijkstra con la tabla de edges. Usar gid_int como id si es entero consistente.
    --    Nota: Filtramos r.edge > 0 (pgr_dijkstra deja -1 en filas de inicio/final)
    --    y luego agregamos las geometrías en orden r.seq para coleccionarlas correctamente.
    WITH dijkstra_result AS (
        SELECT r.seq, r.edge
        FROM pgr_dijkstra(
            'SELECT gid_int AS id, source::integer AS source, target::integer AS target,
                    ST_Length(geom::geography) AS cost
             FROM public.v_sig_vias',
            v_start_node,
            v_end_node,
            false
        ) AS r
        WHERE r.edge > 0
        ORDER BY r.seq
    ),
    ruta_edges AS (
        SELECT v.geom
        FROM dijkstra_result dr
        JOIN public.v_sig_vias v
          ON v.gid_int = dr.edge
        -- ORDER BY dr.seq is already applied in dijkstra_result
    )
    -- 4) Coleccionar en orden y convertir a MultiLineString
    SELECT ST_Multi(ST_LineMerge(ST_Collect(geom))) INTO v_geom_total
    FROM ruta_edges;

    -- Si no hay geometría (ruta vacía) devolvemos NULL
    IF v_geom_total IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN v_geom_total;
END;
$function$;


