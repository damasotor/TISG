package uy.transporte.rest;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import uy.transporte.entity.Linea;
import uy.transporte.entity.Parada;
import uy.transporte.repository.ParadaRepository;

import java.util.List;

@Path("/paradas")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ParadaResource {

    private final ParadaRepository paradaRepository = new ParadaRepository();

    @POST
    public Response crearParada(Parada p) {
        try {
            paradaRepository.crear(p);
            return Response.ok()
                    .entity("{\"mensaje\":\"Parada creada correctamente\"}")
                    .build();
        } catch (Exception e) {
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\":\"No se pudo crear la parada: " + e.getMessage() + "\"}")
                    .build();
        }
    }

    //lineas cercanas a parada
    @GET
    @Path("/{id}/lineas")
    public Response getLineasCercanas(@PathParam("id") Long id) {
        try {
            List<Linea> lineas = paradaRepository.findLineasByProximidad(id);
            return Response.ok(lineas).build();
        } catch (Exception e) {
            e.printStackTrace();
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(e.getMessage())
                    .build();
        }
    }

    @GET
    @Path("/check-db")
    public Response checkDB() {
        boolean ok = paradaRepository.verificarConexion();
        if (ok) {
            return Response.ok("{\"status\":\"Conexión OK\"}").build();
        } else {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"status\":\"Error de conexión a la base\"}")
                    .build();
        }
    }
}
