CREATE OR REPLACE FUNCTION public.registrar_linea(
    p_codigo   text,
    p_origen   text,
    p_destino  text,
    p_empresa  text,
    p_geomjson json
) RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_linea_id   bigint;
    v_geom       geometry;
    v_empresa_id integer;
BEGIN
    -- 1) Buscar empresa por nombre
    SELECT id INTO v_empresa_id
    FROM public.empresas
    WHERE nombre = p_empresa
    LIMIT 1;

    IF v_empresa_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Empresa no encontrada: ' || p_empresa
        );
    END IF;

    -- 2) Convertir GeoJSON a geometry 4326
    v_geom := ST_SetSRID(
                  ST_LineMerge(
                      ST_GeomFromGeoJSON(p_geomjson::text)
                  ),
                  4326
              );

    IF v_geom IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Geometría inválida'
        );
    END IF;

    -- 3) Insertar la línea
    INSERT INTO public.lineas(codigo, origen, destino, empresa_id, geom)
    VALUES (p_codigo, p_origen, p_destino, v_empresa_id, v_geom)
    RETURNING id INTO v_linea_id;

    -- 4) Asociar paradas dentro de 120 metros
    PERFORM asociar_linea_a_paradas(v_linea_id, 120);

    -- 5) Responder
    RETURN json_build_object(
        'success', true,
        'linea_id', v_linea_id
    );
END;
$function$;

