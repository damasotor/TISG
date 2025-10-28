// Esta entidad representa cada fila del resultado de pgr_dijkstra
package uy.transporte.entity;

import jakarta.persistence.*;
import org.locationtech.jts.geom.LineString;
import jakarta.json.bind.annotation.JsonbTypeAdapter;
import uy.transporte.json.GeometryAdapter;

// Se usa @Entity para mapear los resultados de la NativeQuery
@Entity
@SqlResultSetMapping(
    name = "RutaMapping",
    entities = @EntityResult(
        entityClass = RutaSegmento.class,
        fields = {
            @FieldResult(name = "seq", column = "seq"),
            @FieldResult(name = "edge", column = "edge"),
            @FieldResult(name = "cost", column = "cost"),
            @FieldResult(name = "aggCost", column = "agg_cost"),
            @FieldResult(name = "geom", column = "geom")
        }
    )
)
public class RutaSegmento {

    @Id
    // Usamos el campo 'seq' como ID para el mapeo, aunque no es una clave real
    private Long seq;
    
    private Long edge;
    private double cost;
    private double aggCost;

    @JsonbTypeAdapter(GeometryAdapter.class)
    @Column(columnDefinition = "geometry(LineString,32721)")
    private LineString geom;

    // Getters y Setters...
    public Long getSeq() { return seq; }
    public void setSeq(Long seq) { this.seq = seq; }
    public Long getEdge() { return edge; }
    public void setEdge(Long edge) { this.edge = edge; }
    public double getCost() { return cost; }
    public void setCost(double cost) { this.cost = cost; }
    public double getAggCost() { return aggCost; }
    public void setAggCost(double aggCost) { this.aggCost = aggCost; }
    public LineString getGeom() { return geom; }
    public void setGeom(LineString geom) { this.geom = geom; }
}
