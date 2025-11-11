package uy.transporte.entity;

import jakarta.persistence.*;
import org.locationtech.jts.geom.LineString;
import jakarta.json.bind.annotation.JsonbTypeAdapter;
import uy.transporte.json.GeometryAdapter;

@Entity
@Table(name = "lineas")
public class Linea {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String codigo;
    private String origen;
    private String destino;
    private String empresa;

    @JsonbTypeAdapter(GeometryAdapter.class)
    @Column(columnDefinition = "geometry(LineString,32721)")
    private LineString geom;

    public Linea() {}

    // Getters, setters

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getCodigo() {
        return codigo;
    }

    public void setCodigo(String codigo) {
        this.codigo = codigo;
    }

    public String getOrigen() {
        return origen;
    }

    public void setOrigen(String origen) {
        this.origen = origen;
    }

    public String getDestino() {
        return destino;
    }

    public void setDestino(String destino) {
        this.destino = destino;
    }

    public String getEmpresa() {
        return empresa;
    }

    public void setEmpresa(String empresa) {
        this.empresa = empresa;
    }

    public LineString getGeom() {
        return geom;
    }

    public void setGeom(LineString geom) {
        this.geom = geom;
    }
}