package uy.transporte.repository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.Persistence;
import jakarta.persistence.PersistenceContext;
import jakarta.transaction.Transactional;
import uy.transporte.entity.Linea;

import java.util.List;

@ApplicationScoped
public class LineaRepository {

    private static final EntityManagerFactory emf =
            Persistence.createEntityManagerFactory("MiPersistencia");

    public List<Linea> findAll() {
        EntityManager em = emf.createEntityManager();
        return em.createQuery("SELECT l FROM Linea l", Linea.class).getResultList();
    }

    public void crear(Linea linea) {
        EntityManager em = emf.createEntityManager();
        try{
            em.getTransaction().begin();
            em.persist(linea);
            em.getTransaction().commit();
            System.out.println("Linea creada: " + linea.getCodigo());
        } catch (Exception e) {
            em.getTransaction().rollback();
            System.err.println("Error al crear Linea: " + e.getMessage());
            throw new RuntimeException(e);
        } finally {
            em.close();
        }
    }
}
