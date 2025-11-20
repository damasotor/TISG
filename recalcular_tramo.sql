CREATE OR REPLACE FUNCTION calcular_tramo(p1 geometry, p2 geometry)
RETURNS geometry
LANGUAGE plpgsql AS
$$
DECLARE
    n_ini integer;
    n_fin integer;
    v_geom geometry;
BEGIN
    -- Encontrar nodo más cercano a p1
    SELECT CASE
        WHEN ST_Distance(p1::geography, ST_StartPoint(v.geom)::geography)
             < ST_Distance(p1::geography, ST_EndPoint(v.geom)::geography)
        THEN v.source
        ELSE v.target
    END INTO n_ini
    FROM v_sig_vias v
    ORDER BY ST_Distance(p1::geography, v.geom::geography)
    LIMIT 1;

    -- Encontrar nodo más cercano a p2
    SELECT CASE
        WHEN ST_Distance(p2::geography, ST_StartPoint(v.geom)::geography)
             < ST_Distance(p2::geography, ST_EndPoint(v.geom)::geography)
        THEN v.source
        ELSE v.target
    END INTO n_fin
    FROM v_sig_vias v
    ORDER BY ST_Distance(p2::geography, v.geom::geography)
    LIMIT 1;

    -- Ejecutar Dijkstra
    WITH ruta AS (
        SELECT v.geom
        FROM pgr_dijkstra(
            'SELECT gid_int AS id, source, target,
                    ST_Length(geom::geography) AS cost
             FROM v_sig_vias',
            n_ini, n_fin, false
        ) AS r
        JOIN v_sig_vias v ON v.gid_int = r.edge
    )
    SELECT ST_Multi(ST_LineMerge(ST_Union(geom)))
    INTO v_geom
    FROM ruta;

    RETURN v_geom;
END;
$$;

