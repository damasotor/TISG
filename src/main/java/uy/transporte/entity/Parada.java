package uy.transporte.entity;

import jakarta.json.bind.annotation.JsonbTypeAdapter;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import uy.transporte.json.GeometryAdapter;

@Entity
@Table(name = "paradas")
public class Parada {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String nombre;
    private Double lat;
    private Double lon;


    @JsonbTypeAdapter(GeometryAdapter.class)
    @Column(columnDefinition = "geometry(Point,4326)")
    @JdbcTypeCode(SqlTypes.GEOMETRY)
    private Point geom;

    public void generarGeometry() {
        GeometryFactory gf = new GeometryFactory(new PrecisionModel(), 4326);
        this.geom = gf.createPoint(new Coordinate(this.lon, this.lat));
    }

    public Parada() {}

    // Getters y Setters

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public Double getLat() {
        return lat;
    }

    public void setLat(Double lat) {
        this.lat = lat;
    }

    public Double getLon() {
        return lon;
    }

    public void setLon(Double lon) {
        this.lon = lon;
    }

    public Point getGeometry() {
        return geom;
    }

    public void setGeometry(Point geometry) {
        this.geom = geometry;
    }
}
