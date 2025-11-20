CREATE OR REPLACE FUNCTION public.registrar_ruta_con_via(
    id_inicio integer,
    via_lon double precision,
    via_lat double precision,
    id_fin integer
) RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_geom geometry;
    v_distancia double precision;
BEGIN
    v_geom := calcular_ruta_con_via(id_inicio, via_lon, via_lat, id_fin);

    IF v_geom IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'message', 'No se pudo generar la ruta con via'
        );
    END IF;

    v_distancia := ST_Length(v_geom::geography);

    RETURN json_build_object(
        'success', true,
        'geom', ST_AsGeoJSON(v_geom),
        'distancia_m', v_distancia
    );
END;
$function$;

