-- Elimina funciones antiguas
DROP FUNCTION IF EXISTS public.calcular_ruta(integer, integer);
DROP FUNCTION IF EXISTS public.registrar_ruta(integer, integer);

CREATE OR REPLACE FUNCTION public.calcular_ruta(inicio INTEGER, fin INTEGER)
RETURNS geometry AS $$
DECLARE
    v_geom_total geometry;
BEGIN
    WITH
    p_ini AS (
        SELECT CASE 
            WHEN ST_Distance(ST_Transform(p.geom,4326)::geography,
                             ST_Transform(ST_StartPoint(v.geom),4326)::geography)
                 < ST_Distance(ST_Transform(p.geom,4326)::geography,
                               ST_Transform(ST_EndPoint(v.geom),4326)::geography)
            THEN v.source
            ELSE v.target
        END AS nodo
        FROM public.paradas p
        JOIN public.v_sig_vias v
          ON ST_DWithin(ST_Transform(p.geom,4326)::geography,
                        ST_Transform(v.geom,4326)::geography, 150)
        WHERE p.id = inicio
        LIMIT 1
    ),
    p_fin AS (
        SELECT CASE 
            WHEN ST_Distance(ST_Transform(p.geom,4326)::geography,
                             ST_Transform(ST_StartPoint(v.geom),4326)::geography)
                 < ST_Distance(ST_Transform(p.geom,4326)::geography,
                               ST_Transform(ST_EndPoint(v.geom),4326)::geography)
            THEN v.source
            ELSE v.target
        END AS nodo
        FROM public.paradas p
        JOIN public.v_sig_vias v
          ON ST_DWithin(ST_Transform(p.geom,4326)::geography,
                        ST_Transform(v.geom,4326)::geography, 150)
        WHERE p.id = fin
        LIMIT 1
    ),
    ruta_calc AS (
        SELECT ST_Transform(v.geom,4326) AS geom
        FROM pgr_dijkstra(
            'SELECT CAST("GID" AS integer) AS id,
                    CAST(source AS integer) AS source,
                    CAST(target AS integer) AS target,
                    ST_Length(ST_Transform(geom,4326)::geography) AS cost
             FROM public.v_sig_vias',
            (SELECT nodo FROM p_ini),
            (SELECT nodo FROM p_fin),
            false
        ) AS r
        JOIN public.v_sig_vias v
            ON v."GID"::integer = r.edge
    )
    SELECT ST_Multi(ST_LineMerge(ST_Union(geom))) INTO v_geom_total
    FROM ruta_calc;

    RETURN v_geom_total;
END;
$$ LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION public.registrar_ruta(id_inicio integer, id_fin integer)
RETURNS json AS
$$
DECLARE
    v_geom geometry;
    v_distancia double precision;
BEGIN
    -- Manejar caso inicio = fin
    IF id_inicio = id_fin THEN
        RETURN json_build_object(
            'success', true,
            'geom', ST_AsGeoJSON(ST_Multi(ST_GeomFromText('MULTILINESTRING EMPTY', 4326))),
            'distancia_m', 0
        );
    END IF;

    BEGIN
        -- Calcular ruta
        v_geom := calcular_ruta(id_inicio, id_fin);

        IF v_geom IS NULL THEN
            RETURN json_build_object(
                'success', false,
                'message', 'No se pudo generar la ruta: ruta vacía'
            );
        END IF;

        -- Calcular distancia
        v_distancia := ST_Length(v_geom::geography);

        -- Guardar en tabla
        INSERT INTO rutas_resultado(start_stop_id, end_stop_id, route_geom, total_distance)
        VALUES (id_inicio, id_fin, v_geom, v_distancia);

        -- Devolver GeoJSON con cast seguro
        RETURN json_build_object(
            'success', true,
            'geom', ST_AsGeoJSON(v_geom::geometry),
            'distancia_m', v_distancia
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN json_build_object(
                'success', false,
                'message', 'Error de base de datos: ' || SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql;


