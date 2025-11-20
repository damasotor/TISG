CREATE OR REPLACE FUNCTION actualizar_paradas_huerfanas()
RETURNS void AS $$
BEGIN
    UPDATE paradas
    SET enabled = FALSE
    WHERE id NOT IN (
        SELECT parada_id FROM parada_linea WHERE habilitada = TRUE
    );

    UPDATE paradas
    SET enabled = TRUE
    WHERE id IN (
        SELECT parada_id FROM parada_linea WHERE habilitada = TRUE
    );
END;
$$ LANGUAGE plpgsql;

