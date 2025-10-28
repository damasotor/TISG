package uy.transporte.rest;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.LineString;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.geojson.GeoJsonReader;
import uy.transporte.dto.LineaDTO;
import uy.transporte.entity.Linea;
import uy.transporte.repository.LineaRepository;

import java.util.List;

@Path("/lineas")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class LineaResource {

    private final LineaRepository lineaRepository = new LineaRepository();

    @GET
    public List<Linea> getAll() {
        return lineaRepository.findAll();
    }

    @POST
    public Response create(LineaDTO dto) {
        try {
            Linea linea = new Linea();
            linea.setCodigo(dto.getCodigo());
            linea.setOrigen(dto.getOrigen());
            linea.setDestino(dto.getDestino());
            linea.setEmpresa(dto.getEmpresa());

            // 🔹 Acá va el bloque que convierte el GeoJSON en LineString
            try {
                GeoJsonReader reader = new GeoJsonReader();
                Geometry geom = reader.read(dto.getGeom()); // el JSON string con la geometría
                geom.setSRID(32721);
                linea.setGeom((LineString) geom);
            } catch (ParseException e) {
                throw new RuntimeException("Error al parsear GeoJSON: " + e.getMessage(), e);
            }

            // 🔹 Guardamos la entidad
            lineaRepository.crear(linea);

            return Response.status(Response.Status.CREATED).entity(linea).build();

        } catch (Exception e) {
            e.printStackTrace();
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(e.getMessage())
                    .build();
        }
    }
}