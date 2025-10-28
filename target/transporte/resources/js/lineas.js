window.addEventListener("load", () => {
  console.log("Cargando módulo de líneas...");

  const map = window.map;

  // --- Fuente vectorial y capa ---
  const lineasSource = new ol.source.Vector();

  const lineasLayer = new ol.layer.Vector({
    source: lineasSource,
    style: new ol.style.Style({
      stroke: new ol.style.Stroke({
        color: "#FF0000",
        width: 3,
      }),
    }),
  });

  map.addLayer(lineasLayer);

  // ✅ Función local que usa lineasSource correctamente
  async function cargarLineas() {
    try {
      const res = await fetch("http://localhost:8081/transporte/api/lineas");
      const data = await res.json();

      const format = new ol.format.GeoJSON();
      const features = data.map((linea) => {
        const geomObj = JSON.parse(linea.geom);
        const geom = format.readGeometry(geomObj);
        geom.transform("EPSG:32721", "EPSG:3857");

        const f = new ol.Feature({ geometry: geom });
        f.setProperties({
          codigo: linea.codigo,
          origen: linea.origen,
          destino: linea.destino,
          empresa: linea.empresa,
        });
        return f;
      });

      lineasSource.clear();
      lineasSource.addFeatures(features);
      console.log(`✅ ${features.length} líneas cargadas.`);
    } catch (err) {
      console.error("Error cargando líneas:", err);
    }
  }

  // --- Llamada inicial (dentro del load, luego de definir lineasSource)
  cargarLineas();

  // --- Mostrar info al clickear sobre una línea ---
  map.on("singleclick", (evt) => {
    if (window.modoActual) return; // si estamos agregando, ignorar
    map.forEachFeatureAtPixel(evt.pixel, (feature) => {
      const props = feature.getProperties();
      if (props.codigo) {
        const info = `
          Código: ${props.codigo}
          Origen: ${props.origen}
          Destino: ${props.destino}
          Empresa: ${props.empresa}
        `;
        alert("🚌 Línea\n" + info.replace(/<br>/g, "\n"));
      }
    });
  });

  // --- Modo agregar línea ---
  const drawLinea = new ol.interaction.Draw({
    source: lineasSource,
    type: "LineString",
  });

  function activarAltaLinea() {
    window.modoActual = "linea";
    window.actualizarBannerModo();
    map.addInteraction(drawLinea);
    alert("✏️ Dibuje la línea (doble clic o Enter para finalizar).");

    drawLinea.once("drawend", async (evt) => {
      map.removeInteraction(drawLinea);
      window.modoActual = null;
      window.actualizarBannerModo();

      const geom = evt.feature.getGeometry().clone().transform("EPSG:3857", "EPSG:32721");
      const geojson = new ol.format.GeoJSON().writeGeometryObject(geom);

      const lineaData = {
        codigo: prompt("Código de línea (ej: 104-este):"),
        origen: prompt("Origen:"),
        destino: prompt("Destino:"),
        empresa: prompt("Empresa:"),
        geom: JSON.stringify(geojson),
      };

      try {
        const r = await fetch("http://localhost:8081/transporte/api/lineas", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(lineaData),
        });

        if (r.ok) {
          alert("✅ Línea creada correctamente");
          cargarLineas(); // recarga el mapa con la nueva línea
        } else {
          const txt = await r.text();
          console.error("Error:", txt);
          alert("❌ Error al crear línea:\n" + txt);
        }
      } catch (err) {
        console.error("Error guardando línea:", err);
      }
    });
  }
  function cancelarDibujo() {
    // Si hay una interacción de dibujo activa, la removemos
    map.removeInteraction(drawLinea);

    // Volvemos a modo libre
    window.modoActual = null;
    window.actualizarBannerModo();

    alert("❌ Dibujo cancelado.");
  }

  window.activarAltaLinea = activarAltaLinea;
  window.cancelarDibujo = cancelarDibujo;
});
