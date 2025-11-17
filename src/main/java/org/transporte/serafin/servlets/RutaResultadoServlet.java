package org.transporte.serafin.servlets;

import jakarta.servlet.http.*;
import java.io.IOException;
import java.sql.*;
import org.json.JSONObject;

public class RutaResultadoServlet extends HttpServlet {

    private static final String DB_URL = "jdbc:postgresql://postgis_transporte_serafin:5432/transporte";
    private static final String DB_USER = "admin";
    private static final String DB_PASS = "admin";

    static {
        try { Class.forName("org.postgresql.Driver"); }
        catch (Exception e) { throw new RuntimeException(e); }
    }

    @Override
    protected void doPut(HttpServletRequest req, HttpServletResponse resp) throws IOException {

        JSONObject out = new JSONObject();
        resp.setContentType("application/json");

        try {
            String body = req.getReader().lines().reduce("", (a,b)->a+b);
            JSONObject json = new JSONObject(body);

            int id = json.getInt("id");
            String wkt = json.getString("wkt");

            try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {

                String sql =
                        "UPDATE rutas_resultado SET route_geom = ST_SetSRID(ST_GeomFromText(?), 4326) WHERE id = ?";

                PreparedStatement ps = conn.prepareStatement(sql);
                ps.setString(1, wkt);
                ps.setInt(2, id);

                int rows = ps.executeUpdate();
                if (rows > 0) {
                    out.put("status", "ok");
                    out.put("message", "Ruta guardada correctamente.");
                } else {
                    out.put("status", "not_found");
                }
            }

        } catch (Exception e) {
            out.put("status", "error");
            out.put("message", e.getMessage());
        }

        resp.getWriter().write(out.toString());
    }
}
