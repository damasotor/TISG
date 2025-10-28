package uy.transporte.dto;

import java.io.Serializable;

public class RutaDTO implements Serializable {
    private String geojson; // Contendrá la geometría de la ruta en formato GeoJSON
    private double costoTotal;
    // Otros campos si quieres incluir detalles de los segmentos

    public RutaDTO() {
    }

    public RutaDTO(String geojson, double costoTotal) {
        this.geojson = geojson;
        this.costoTotal = costoTotal;
    }

    // Getters y Setters...
    public String getGeojson() { return geojson; }
    public void setGeojson(String geojson) { this.geojson = geojson; }
    public double getCostoTotal() { return costoTotal; }
    public void setCostoTotal(double costoTotal) { this.costoTotal = costoTotal; }
}
