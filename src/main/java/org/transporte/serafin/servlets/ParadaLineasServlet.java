package org.transporte.serafin.servlets;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.sql.*;
import java.util.stream.Collectors;

import org.json.JSONArray;
import org.json.JSONObject;

@WebServlet("/api/paradaLineas")
public class ParadaLineasServlet extends HttpServlet {

    private static final String DB_URL  = "jdbc:postgresql://localhost:5432/transporte";
    private static final String DB_USER = "admin";   // usa las mismas credenciales que en los otros servlets que FUNCIONAN
    private static final String DB_PASS = "admin";

    static {
        try {
            Class.forName("org.postgresql.Driver");
            System.out.println(">>> Driver PostgreSQL cargado en ParadaLineasServlet");
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");

        JSONObject json = new JSONObject();

        String paradaIdStr = req.getParameter("paradaId");
        if (paradaIdStr == null) {
            json.put("success", false);
            json.put("error", "Falta parámetro paradaId");
            resp.getWriter().write(json.toString());
            return;
        }

        int paradaId;
        try {
            paradaId = Integer.parseInt(paradaIdStr);
        } catch (NumberFormatException e) {
            json.put("success", false);
            json.put("error", "paradaId debe ser entero");
            resp.getWriter().write(json.toString());
            return;
        }

        String sql =
            "SELECT pl.linea_id, l.codigo, pl.horarios, pl.habilitada " +
            "FROM parada_linea pl " +
            "JOIN lineas l ON l.id = pl.linea_id " +
            "WHERE pl.parada_id = ? " +
            "ORDER BY l.codigo";

        try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setInt(1, paradaId);

            try (ResultSet rs = ps.executeQuery()) {
                JSONArray arr = new JSONArray();

                while (rs.next()) {
                    JSONObject o = new JSONObject();
                    o.put("linea_id", rs.getInt("linea_id"));
                    o.put("codigo", rs.getString("codigo"));

                    String horariosStr = rs.getString("horarios");
                    if (horariosStr == null || horariosStr.isBlank()) {
                        o.put("horarios", new JSONArray());
                    } else {
                        try {
                            o.put("horarios", new JSONArray(horariosStr));
                        } catch (Exception ex) {
                            // Por si el texto no es JSON válido
                            JSONArray ha = new JSONArray();
                            ha.put(horariosStr);
                            o.put("horarios", ha);
                        }
                    }

                    o.put("habilitada", rs.getBoolean("habilitada"));

                    arr.put(o);
                }

                json.put("success", true);
                json.put("paradaId", paradaId);
                json.put("lineas", arr);
            }

        } catch (Exception e) {
            e.printStackTrace();
            json.put("success", false);
            json.put("error", e.getMessage());
        }

        resp.getWriter().write(json.toString());
    }
}

