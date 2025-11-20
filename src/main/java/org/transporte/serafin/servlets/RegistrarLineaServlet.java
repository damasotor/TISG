package org.transporte.serafin.servlets;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import jakarta.servlet.annotation.*;
import java.io.*;
import java.sql.*;
import org.json.JSONObject;

@WebServlet("/api/registrarLinea")
public class RegistrarLineaServlet extends HttpServlet {

    private static final String DB_URL  = "jdbc:postgresql://localhost:5432/transporte";
    private static final String DB_USER = "admin";
    private static final String DB_PASS = "admin";

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {

        resp.setContentType("application/json; charset=UTF-8");
        JSONObject json = new JSONObject();

        try {
            String codigo   = req.getParameter("codigo");
            String origen   = req.getParameter("origen");
            String destino  = req.getParameter("destino");
            String empresa  = req.getParameter("empresa");
            String geomJson = req.getParameter("geom");

            if (codigo == null || origen == null || destino == null || empresa == null || geomJson == null) {
                json.put("success", false);
                json.put("error", "Faltan parámetros");
                resp.getWriter().write(json.toString());
                return;
            }

            try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {

                String sql = "SELECT registrar_linea(?, ?, ?, ?, ?::json) AS resultado";

                try (PreparedStatement ps = conn.prepareStatement(sql)) {
                    ps.setString(1, codigo);
                    ps.setString(2, origen);
                    ps.setString(3, destino);
                    ps.setString(4, empresa);
                    ps.setString(5, geomJson);

                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            JSONObject resultado = new JSONObject(rs.getString("resultado"));
                            resp.getWriter().write(resultado.toString());
                            return;
                        }
                    }
                }
            }

            json.put("success", false);
            json.put("error", "No se obtuvo respuesta");
            resp.getWriter().write(json.toString());

        } catch (Exception e) {
            e.printStackTrace();
            json.put("success", false);
            json.put("error", e.getMessage());
            resp.getWriter().write(json.toString());
        }
    }
}

