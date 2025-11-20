CREATE OR REPLACE FUNCTION asociar_paradas_a_linea(p_linea_id INT)
RETURNS void AS $$
BEGIN
    INSERT INTO parada_linea(parada_id, linea_id)
    SELECT p.id, p_linea_id
    FROM paradas p
    JOIN lineas l ON l.id = p_linea_id
    WHERE ST_DWithin(
        p.geom::geography,
        l.geom::geography,
        10
    )
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

