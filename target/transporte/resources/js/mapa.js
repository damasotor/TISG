// Archivo: ./main/webapp/resources/js/mapa.js

// --- Cargar el mapa ---
window.addEventListener("load", () => {
  console.log("Inicializando mapa...");

  // --- Definir EPSG:32721 (UTM 21S) Antes de cargar el mapa---
  proj4.defs("EPSG:32721", "+proj=utm +zone=21 +south +datum=WGS84 +units=m +no_defs");
  ol.proj.proj4.register(proj4);

  const baseLayer = new ol.layer.Tile({
    source: new ol.source.OSM(),
  });

  const paradasLayer = new ol.layer.Tile({
    source: new ol.source.TileWMS({
      url: "http://localhost:8080/geoserver/transporte/wms",
      params: {
        LAYERS: "transporte:paradas",
        TILED: true,
        VERSION: "1.1.1",
        FORMAT: "image/png",
      },
      serverType: "geoserver",
      crossOrigin: "anonymous",
    }),
  });

  const map = new ol.Map({
    target: "map",
    layers: [baseLayer, paradasLayer],
    view: new ol.View({
      center: ol.proj.fromLonLat([-56.1645, -34.9011]),
      zoom: 13,
    }),
  });

  // --- Exponer globalmente ---
  window.map = map;
  window.paradasLayer = paradasLayer;

  // --- Estado global ---
  // "parada" | "linea" | "ruteo"
  window.modoActual = null; 
  // array para guardar las coordenadas [lon, lat] del Origen y Destino de la ruta
  window.puntosRuta = []; 


  console.log("Mapa listo");

  // Función global para mostrar el modo actual en el banner
  window.actualizarBannerModo = function () {
    const banner = document.getElementById("modo-banner");
    const modo = window.modoActual;

    if (modo === "parada") {
      banner.textContent = "Modo: Parada (clic para agregar)";
    } else if (modo === "linea") {
      banner.textContent = "Modo: Línea (doble clic o Enter para finalizar)";
    } else if (modo === "ruteo") { // 🔹 Lógica para el modo Ruteo
        const numPuntos = window.puntosRuta.length;
        if (numPuntos === 0) {
            banner.textContent = "Modo: Ruteo (clic en Origen)";
        } else {
            banner.textContent = "Modo: Ruteo (clic en Destino)";
        }
    } else {
      banner.textContent = "Modo: Libre";
    }
  };
  
  // 🔹 Función global para activar el modo de ruteo
  window.activarRuteo = function () {
      window.modoActual = "ruteo";
      window.puntosRuta = []; // Resetear puntos al inicio
      window.actualizarBannerModo();
      alert("📍 Modo RUTEO activado. Haga clic en el mapa para seleccionar el punto de ORIGEN.");
  };

});
