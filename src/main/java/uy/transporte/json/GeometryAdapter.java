package uy.transporte.json;

import jakarta.json.bind.adapter.JsonbAdapter;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.io.geojson.GeoJsonReader;
import org.locationtech.jts.io.geojson.GeoJsonWriter;

/**
 * Adaptador JSON-B para serializar y deserializar geometrías JTS (Point, LineString, etc.)
 * en formato GeoJSON.
 */
public class GeometryAdapter implements JsonbAdapter<Geometry, String> {

    @Override
    public String adaptToJson(Geometry geom) {
        if (geom == null) return null;
        GeoJsonWriter writer = new GeoJsonWriter();
        return writer.write(geom);
    }

    @Override
    public Geometry adaptFromJson(String json) {
        if (json == null || json.isBlank()) return null;
        try {
            GeoJsonReader reader = new GeoJsonReader();
            return reader.read(json);
        } catch (Exception e) {
            throw new RuntimeException("Error al parsear GeoJSON: " + e.getMessage(), e);
        }
    }
}
