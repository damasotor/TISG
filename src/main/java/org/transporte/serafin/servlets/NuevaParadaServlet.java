package org.transporte.serafin.servlets;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.*;
import org.json.JSONObject;

// ya esta registrado @WebServlet("/api/nuevaParada/*")
public class NuevaParadaServlet extends HttpServlet {

    private static final String DB_URL = "jdbc:postgresql://localhost:5432/transporte";
    private static final String DB_USER = "admin";
    private static final String DB_PASS = "admin";

    static {
        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            throw new RuntimeException("ERROR: No se encontró el driver JDBC.", e);
        }
    }

    private void setCorsHeaders(HttpServletResponse resp) {
        resp.setHeader("Access-Control-Allow-Origin", "*");
        resp.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        resp.setHeader("Access-Control-Allow-Headers", "Content-Type");
    }

    @Override
    protected void doOptions(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        setCorsHeaders(resp);
        resp.setStatus(HttpServletResponse.SC_NO_CONTENT);
    }

    // ==========================================================
    // POST (Crear nueva parada)
    // ==========================================================
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        setCorsHeaders(resp);
        resp.setContentType("application/json; charset=UTF-8");

        JSONObject out = new JSONObject();

        try {
            String body = req.getReader().lines().reduce("", (a, b) -> a + b);
            JSONObject json = new JSONObject(body);

            String nombre = json.optString("nombre", "Sin nombre");
            double lon = json.getDouble("lon");
            double lat = json.getDouble("lat");

            try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {
                String sql = "INSERT INTO paradas (nombre, geom) VALUES (?, ST_SetSRID(ST_MakePoint(?, ?), 4326))";

                try (PreparedStatement ps = conn.prepareStatement(sql)) {
                    ps.setString(1, nombre);
                    ps.setDouble(2, lon);
                    ps.setDouble(3, lat);
                    ps.executeUpdate();
                }

                out.put("status", "ok");
                out.put("message", "Parada registrada correctamente.");
            }

        } catch (Exception e) {
            e.printStackTrace();
            out.put("status", "error_general");
            out.put("message", e.getMessage());
            resp.setStatus(400);
        }

        resp.getWriter().write(out.toString());
    }

    // ==========================================================
    // DELETE /api/nuevaParada/{id}
    // ==========================================================
    @Override
    protected void doDelete(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        setCorsHeaders(resp);
        resp.setContentType("application/json; charset=UTF-8");
        JSONObject out = new JSONObject();

        try {
            String pathInfo = req.getPathInfo(); // /{id}

            if (pathInfo == null || pathInfo.length() <= 1) {
                resp.setStatus(400);
                out.put("status", "error");
                out.put("message", "Falta ID en la URL.");
                resp.getWriter().write(out.toString());
                return;
            }

            long id = Long.parseLong(pathInfo.substring(1));

            try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {
               String sql = "DELETE FROM paradas WHERE id = ?";
                PreparedStatement ps = conn.prepareStatement(sql);
                ps.setLong(1, id);


                int rows = ps.executeUpdate();
                if (rows > 0) {
                    out.put("status", "ok");
                    out.put("message", "Parada eliminada.");
                } else {
                    resp.setStatus(404);
                    out.put("status", "not_found");
                    out.put("message", "No se encontró la parada.");
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
            resp.setStatus(400);
            out.put("status", "error_general");
            out.put("message", e.getMessage());
        }

        resp.getWriter().write(out.toString());
    }

    // ==========================================================
    // PUT -> actualizar nombre + posición de una parada
    // ==========================================================
    @Override
    protected void doPut(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        setCorsHeaders(resp);
        resp.setContentType("application/json; charset=UTF-8");
        JSONObject out = new JSONObject();

        try {
            String body = req.getReader().lines().reduce("", (a,b)->a+b);
            JSONObject json = new JSONObject(body);

            long id = json.getLong("id");
            String nombre = json.getString("nombre");
            double lon = json.getDouble("lon");
            double lat = json.getDouble("lat");
            
            try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {
                String sql =
                    "UPDATE paradas " +
                    "SET nombre=?, lon=?, lat=?, geom=ST_SetSRID(ST_MakePoint(?, ?), 4326) " +
                    "WHERE id=?";


                PreparedStatement ps = conn.prepareStatement(sql);
                ps.setString(1, nombre);
                ps.setDouble(2, lon);
                ps.setDouble(3, lat);
                ps.setDouble(4, lon);   // geom x
                ps.setDouble(5, lat);   // geom y
                ps.setLong(6, id);      // where


                int rows = ps.executeUpdate();
                if (rows > 0) {
                    out.put("status", "ok");
                    out.put("message", "Parada actualizada.");
                } else {
                    resp.setStatus(404);
                    out.put("status", "not_found");
                    out.put("message", "No existe la parada.");
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
            resp.setStatus(400);
            out.put("status", "error_general");
            out.put("message", e.getMessage());
        }

        resp.getWriter().write(out.toString());
    }
}
