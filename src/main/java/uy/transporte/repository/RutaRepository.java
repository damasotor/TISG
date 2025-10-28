// Aquí se implementa la lógica de búsqueda de nodos y pgr_dijkstra. Necesitarás importar y agregar la clase RutaSegmento al persistence.xml
package uy.transporte.repository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.Persistence;
import jakarta.persistence.NoResultException;
import uy.transporte.entity.RutaSegmento;
import uy.transporte.entity.RutaSegmento;
import uy.transporte.dto.RutaRequestDTO;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class RutaRepository {

    private static final EntityManagerFactory emf =
            Persistence.createEntityManagerFactory("MiPersistencia");

    public Optional<List<RutaSegmento>> calcularRuta(RutaRequestDTO dto) {
        try (EntityManager em = emf.createEntityManager()) {
            
            // 1. Encuentra el ID del nodo más cercano al Origen (Lon/Lat -> 32721)
            Long idOrigen = (Long) em.createNativeQuery("""
                SELECT id FROM vias_original_vertices_pgr
                ORDER BY the_geom <-> ST_Transform(ST_SetSRID(ST_MakePoint(:lonO, :latO), 4326), 32721)
                LIMIT 1
            """)
                .setParameter("lonO", dto.lonOrigen)
                .setParameter("latO", dto.latOrigen)
                .getSingleResult();

            // 2. Encuentra el ID del nodo más cercano al Destino
            Long idDestino = (Long) em.createNativeQuery("""
                SELECT id FROM vias_original_vertices_pgr
                ORDER BY the_geom <-> ST_Transform(ST_SetSRID(ST_MakePoint(:lonD, :latD), 4326), 32721)
                LIMIT 1
            """)
                .setParameter("lonD", dto.lonDestino)
                .setParameter("latD", dto.latDestino)
                .getSingleResult();

            // ⚠️ Manejo de la Coincidencia: Si son el mismo, no hay ruta (o se requeriría lógica OFFSET)
            if (idOrigen.equals(idDestino)) {
                 System.out.println("Origen y destino coinciden en el nodo: " + idOrigen);
                 return Optional.of(List.of()); // Devuelve lista vacía
            }

            // 3. Ejecuta pgr_dijkstra
            String sql = """
                SELECT
                    route.seq, route.edge, route.cost, route.agg_cost, road.geom
                FROM pgr_dijkstra(
                    'SELECT "GID" AS id, source, target, cost, longitud AS reverse_cost FROM vias_original',
                    :idO,
                    :idD,
                    directed := false
                ) AS route
                INNER JOIN vias_original AS road
                ON route.edge = road."GID"
            """;

            List<RutaSegmento> ruta = em.createNativeQuery(sql, "RutaMapping")
                .setParameter("idO", idOrigen)
                .setParameter("idD", idDestino)
                .getResultList();

            return Optional.of(ruta);

        } catch (NoResultException e) {
             System.out.println("No se encontraron nodos cercanos para el ruteo.");
             return Optional.empty(); // No hay nodos cerca o no hay ruta
        } catch (Exception e) {
            e.printStackTrace();
            throw new RuntimeException("Error calculando ruta: " + e.getMessage(), e);
        }
    }
}
