// recurso REST para manejar la solicitud de ruta y devolver el GeoJSON es la geometría de la ruta para ser dibujada en el mapa y costoTotal: La distancia mínima de la ruta calculada.

/* La función pgr_dijkstra encuentra el camino con el menor costo acumulado (distancia, tiempo o cualquier métrica definida como cost). Este costo total se almacena en la columna agg_cost del último segmento de la ruta.

Al calcular el ruteo, el cliente necesita saber cuál es la longitud total del camino más corto encontrado, que es precisamente el valor de costoTotal devuelto.*/


package uy.transporte.rest;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import uy.transporte.dto.RutaDTO;
import uy.transporte.dto.RutaRequestDTO;
import uy.transporte.entity.RutaSegmento;
import uy.transporte.repository.RutaRepository;
import org.locationtech.jts.io.geojson.GeoJsonWriter;
import org.locationtech.jts.geom.LineString;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.MultiLineString; // NUEVA IMPORTACIÓN
import org.locationtech.jts.geom.GeometryFactory; // NUEVA IMPORTACIÓN

import java.util.List;
import java.util.Optional;

@Path("/ruta")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class RutaResource {

    private final RutaRepository rutaRepository = new RutaRepository();

    @POST
    public Response calcularRuta(RutaRequestDTO dto) {
        try {
            Optional<List<RutaSegmento>> optRuta = rutaRepository.calcularRuta(dto);

            if (optRuta.isEmpty() || optRuta.get().isEmpty()) {
                // No hay ruta, nodos no encontrados, o nodos idénticos
                return Response.status(Response.Status.NOT_FOUND)
                        .entity("{\"error\":\"No se encontró ruta o los puntos están fuera de la red.\"}")
                        .build();
            }

            List<RutaSegmento> ruta = optRuta.get();
            
            // 1. Obtener el Costo Total (es el agg_cost del último segmento)
            double costoTotal = ruta.get(ruta.size() - 1).getAggCost();

            // 2. Construir la MultiLineString GeoJSON para la ruta completa
            
            // Paso A: Recolectar todos los segmentos (LineString) en un array
            LineString[] lineStrings = ruta.stream()
                .map(RutaSegmento::getGeom)
                .toArray(LineString[]::new);

            // Paso B: Crear una única MultiLineString a partir del array de LineStrings
            // Esto es necesario porque GeoJsonWriter.write() solo acepta una Geometry, no un array.
            GeometryFactory geometryFactory = new GeometryFactory();
            MultiLineString multiLineString = geometryFactory.createMultiLineString(lineStrings);

            // Paso C: Serializar la única MultiLineString a GeoJSON
            GeoJsonWriter writer = new GeoJsonWriter();
            String geojson = writer.write(multiLineString); // Se pasa una sola geometría

            RutaDTO resultado = new RutaDTO(geojson, costoTotal);
            
            return Response.ok(resultado).build();

        } catch (Exception e) {
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\":\"Error interno al calcular la ruta: " + e.getMessage() + "\"}")
                    .build();
        }
    }
}

