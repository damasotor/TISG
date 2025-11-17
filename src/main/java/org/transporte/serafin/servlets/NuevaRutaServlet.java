package org.transporte.serafin.servlets;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.ServletException;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

@WebServlet("/api/nuevaRuta")
public class NuevaRutaServlet extends HttpServlet {

    private static final String DB_URL = "jdbc:postgresql://localhost:5432/transporte";
    private static final String DB_USER = "postgres";
    private static final String DB_PASS = "admin";
    
    

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
            
        // --- INICIO DE CÓDIGO CORS ---
        // 1. Permite solicitudes desde cualquier origen (*) para evitar el error CORS.
        resp.setHeader("Access-Control-Allow-Origin", "*"); 
        
        // 2. Permite los métodos que se usarán (aunque aquí solo se use GET)
        resp.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        
        // 3. Permite encabezados específicos (Content-Type es crucial)
        resp.setHeader("Access-Control-Allow-Headers", "Content-Type");
        
        // 4. Manejar el pre-flight request de CORS (método OPTIONS)
        if ("OPTIONS".equalsIgnoreCase(req.getMethod())) {
            resp.setStatus(HttpServletResponse.SC_OK);
            return; // Detiene la ejecución para peticiones OPTIONS
        }
        // --- FIN DE CÓDIGO CORS ---

        resp.setContentType("application/json;charset=UTF-8");
        JSONObject json = new JSONObject();

        String idInicioStr = req.getParameter("idInicio");
        String idFinStr = req.getParameter("idFin");

        if (idInicioStr == null || idFinStr == null) {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            json.put("success", false);
            json.put("error", "Faltan parámetros idInicio o idFin");
            resp.getWriter().write(json.toString());
            return;
        }

        int idInicio, idFin;
        try {
            idInicio = Integer.parseInt(idInicioStr);
            idFin = Integer.parseInt(idFinStr);
        } catch (NumberFormatException e) {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            json.put("success", false);
            json.put("error", "idInicio y idFin deben ser números enteros");
            resp.getWriter().write(json.toString());
            return;
     	   }

        try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {

            String sql = "SELECT registrar_ruta(?, ?) AS resultado";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, idInicio);
                ps.setInt(2, idFin);

                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        String resultado = rs.getString("resultado");
                        System.out.println(">>> registrar_ruta devolvió: " + resultado);

                        if (resultado == null || resultado.trim().isEmpty()) {
                            resp.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
                            json.put("success", false);
                            json.put("error", "La función registrar_ruta devolvió NULL o vacío");
                        } else {
                            try {
                                JSONObject obj = new JSONObject(resultado);
                                boolean success = obj.optBoolean("success", false);
                                json.put("success", success);

                                if (success) {
                                    String geomStr = obj.optString("geom", "{}");
                                    try {
                                        JSONObject geom = new JSONObject(geomStr);
                                        json.put("coordinates", geom.optJSONArray("coordinates"));
                                    } catch (JSONException ge) {
                                        System.err.println("Error al parsear geom JSON: " + geomStr);
                                        json.put("coordinates", new JSONArray());
                                    }
                                } else {
                                    json.put("error", obj.optString("message", "Error desconocido"));
                                }

                            } catch (JSONException je) {
                                resp.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
                                json.put("success", false);
                                json.put("error", "JSON inválido devuelto por registrar_ruta: " + resultado);
                                je.printStackTrace();
                            }
                        }

                    } else {
                        resp.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
                        json.put("success", false);
                        json.put("error", "Sin resultados de la función registrar_ruta");
                    }
                }
            }

        } catch (SQLException e) {
            resp.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            json.put("success", false);
            json.put("error", "Error de base de datos: " + e.getMessage());
            e.printStackTrace();
        } catch (Exception e) {
            resp.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            json.put("success", false);
            json.put("error", "Error interno del servidor: " + e.getMessage());
            e.printStackTrace();
        }

        try (PrintWriter out = resp.getWriter()) {
            out.print(json.toString());
        }
    }
    
}

