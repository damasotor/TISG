package uy.transporte.repository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.Persistence;
import uy.transporte.entity.Linea;
import uy.transporte.entity.Parada;

import java.util.List;

@ApplicationScoped
public class ParadaRepository {

    private static final EntityManagerFactory emf =
            Persistence.createEntityManagerFactory("MiPersistencia");

    public void crear(Parada p) {
        EntityManager em = emf.createEntityManager();
        try {
            p.generarGeometry(); // crea el POINT
            em.getTransaction().begin();
            em.persist(p);
            em.getTransaction().commit();
            System.out.println("Parada creada: " + p.getNombre());
            //asociarLineasCercanas(p);
            System.out.println("Parada Asociada a Linea: ");
        } catch (Exception e) {
            em.getTransaction().rollback();
            System.err.println("Error al crear parada: " + e.getMessage());
            throw new RuntimeException(e);
        } finally {
            em.close();
        }
    }

    public List<Linea> findLineasByProximidad(Long idParada) {
        EntityManager em = emf.createEntityManager();

        double distancia = 10.0;

        return em.createNativeQuery("""
            SELECT l.*
            FROM lineas l
            JOIN paradas p ON p.id = :id
            WHERE ST_DWithin(
                l.geom,
                ST_Transform(p.geom, 32721),
                :dist
            )
        """, Linea.class)
                .setParameter("id", idParada)
                .setParameter("dist", distancia)
                .getResultList();
    }

//    public void asociarLineasCercanas(Parada parada) {
//        EntityManager em = emf.createEntityManager();
//
//        String sql = """
//        SELECT l.id FROM lineas l
//        WHERE ST_DWithin(
//            l.geom,
//            ST_Transform(ST_SetSRID(ST_MakePoint(:lon, :lat), 4326), 32721),
//            10
//        )
//    """;
//
//        List<Long> ids = em.createNativeQuery(sql)
//                .setParameter("lon", parada.getLon())
//                .setParameter("lat", parada.getLat())
//                .getResultList();
//
//        for (Long idLinea : ids) {
//            ParadaLinea pl = new ParadaLinea();
//            pl.setParada(parada);
//            pl.setLinea(em.find(Linea.class, idLinea));
//            em.persist(pl);
//        }
//    }

    public boolean verificarConexion() {
        try (EntityManager em = emf.createEntityManager()) {
            em.createNativeQuery("SELECT 1").getSingleResult();
            return true;
        } catch (Exception e) {
            System.err.println("Error verificando conexión: " + e.getMessage());
            return false;
        }
    }
}
