package org.transporte.serafin.servlets;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.sql.*;

import org.json.JSONObject;

@WebServlet("/api/lineaGeom")
public class LineaGeomServlet extends HttpServlet {

    private static final String DB_URL  = "jdbc:postgresql://localhost:5432/transporte";
    private static final String DB_USER = "admin";
    private static final String DB_PASS = "admin";

    static {
        try {
            Class.forName("org.postgresql.Driver");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {

        resp.setHeader("Access-Control-Allow-Origin", "*");
        resp.setContentType("application/json; charset=UTF-8");

        JSONObject json = new JSONObject();

        String idStr = req.getParameter("idLinea");
        if (idStr == null) {
            json.put("success", false);
            json.put("error", "Falta parámetro idLinea");
            resp.getWriter().write(json.toString());
            return;
        }

        int idLinea;
        try {
            idLinea = Integer.parseInt(idStr);
        } catch (Exception e) {
            json.put("success", false);
            json.put("error", "idLinea inválido");
            resp.getWriter().write(json.toString());
            return;
        }

        String sql = "SELECT ST_AsGeoJSON(geom) AS geom FROM lineas WHERE id = ?";

        try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setInt(1, idLinea);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {

                    String geomStr = rs.getString("geom");

                    if (geomStr == null) {
                        json.put("success", false);
                        json.put("error", "La línea no tiene geometría");
                    } else {
                        json.put("success", true);
                        json.put("geom", new JSONObject(geomStr));
                    }

                } else {
                    json.put("success", false);
                    json.put("error", "Línea no encontrada");
                }
            }

        } catch (Exception e) {
            json.put("success", false);
            json.put("error", e.getMessage());
            e.printStackTrace();
        }

        resp.getWriter().write(json.toString());
    }
}

