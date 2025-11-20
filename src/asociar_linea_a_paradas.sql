CREATE OR REPLACE FUNCTION public.asociar_linea_a_paradas(
    p_linea_id          bigint,
    p_tolerancia_metros double precision DEFAULT 80
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_geom_linea geometry;
BEGIN
    -- Obtener geometría de la línea
    SELECT geom INTO v_geom_linea
    FROM public.lineas
    WHERE id = p_linea_id;

    IF v_geom_linea IS NULL THEN
        RAISE EXCEPTION 'No existe geometría para la línea %', p_linea_id;
    END IF;

    -- Asociar paradas a la línea según distancia al eje
    INSERT INTO public.parada_linea (parada_id, linea_id, horarios, habilitada)
    SELECT 
        p.id,
        p_linea_id,
        '[]'::jsonb,
        TRUE
    FROM public.paradas p
    WHERE 
        ST_Distance(
            ST_ClosestPoint(v_geom_linea, p.geom)::geography,
            p.geom::geography
        ) <= p_tolerancia_metros
    ON CONFLICT (parada_id, linea_id) DO NOTHING;

END;
$$;

