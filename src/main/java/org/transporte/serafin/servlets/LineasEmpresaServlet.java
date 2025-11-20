package org.transporte.serafin.servlets;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.sql.*;
import org.json.JSONArray;
import org.json.JSONObject;

@WebServlet("/api/lineasEmpresa")
public class LineasEmpresaServlet extends HttpServlet {

    private static final String DB_URL  = "jdbc:postgresql://localhost:5432/transporte";
    private static final String DB_USER = "admin";
    private static final String DB_PASS = "admin";

    static {
        try {
            Class.forName("org.postgresql.Driver");
            System.out.println(">>> Driver PostgreSQL cargado en LineasEmpresaServlet");
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json; charset=UTF-8");

        JSONObject json = new JSONObject();

        // Se puede buscar por nombre de empresa o por id
        String empresaNombre = req.getParameter("empresa");
        String empresaIdStr  = req.getParameter("empresaId");

        if ((empresaNombre == null || empresaNombre.isBlank()) &&
            (empresaIdStr == null || empresaIdStr.isBlank())) {
            json.put("success", false);
            json.put("error", "Debe indicar parámetro empresa (nombre) o empresaId");
            resp.getWriter().write(json.toString());
            return;
        }

        String sql =
            "SELECT l.id, l.codigo, l.origen, l.destino, e.id AS empresa_id, e.nombre AS empresa_nombre " +
            "FROM lineas l " +
            "JOIN empresas e ON e.id = l.empresa_id " +
            "WHERE 1=1 ";

        if (empresaIdStr != null && !empresaIdStr.isBlank()) {
            sql += " AND e.id = ? ";
        } else {
            sql += " AND e.nombre ILIKE ? ";
        }

        sql += " ORDER BY l.codigo";

        try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
             PreparedStatement ps = conn.prepareStatement(sql)) {

            if (empresaIdStr != null && !empresaIdStr.isBlank()) {
                ps.setInt(1, Integer.parseInt(empresaIdStr));
            } else {
                ps.setString(1, empresaNombre);      // si querés permitir “LIKE”, usar "%"+empresaNombre+"%"
            }

            try (ResultSet rs = ps.executeQuery()) {
                JSONArray arr = new JSONArray();

                while (rs.next()) {
                    JSONObject o = new JSONObject();
                    o.put("id",           rs.getInt("id"));
                    o.put("codigo",       rs.getString("codigo"));
                    o.put("origen",       rs.getString("origen"));
                    o.put("destino",      rs.getString("destino"));
                    o.put("empresa_id",   rs.getInt("empresa_id"));
                    o.put("empresa",      rs.getString("empresa_nombre"));
                    arr.put(o);
                }

                json.put("success", true);
                json.put("empresa", empresaNombre != null ? empresaNombre : empresaIdStr);
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

