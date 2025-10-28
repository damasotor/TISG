window.addEventListener("load", () => {
  console.log("Cargando módulo de paradas...");

  const map = window.map;
  const paradasLayer = window.paradasLayer;

  const popup = document.getElementById("popup");
  const popupContent = document.getElementById("popup-content");

  const overlay = new ol.Overlay({
    element: popup,
    positioning: "bottom-center",
    stopEvent: false,
    offset: [0, -15],
  });
  map.addOverlay(overlay);

  // --- FUENTE Y CAPA PARA LA RUTA CALCULADA ---
  const rutaSource = new ol.source.Vector();
  const rutaLayer = new ol.layer.Vector({
      source: rutaSource,
      style: new ol.style.Style({
          stroke: new ol.style.Stroke({
              color: 'rgba(50, 200, 50, 0.8)', // Color verde para la ruta
              width: 5
          })
      })
  });
  map.addLayer(rutaLayer);

  function mostrarPopupBonito(coordinate, nombre, lineas = []) {
    let html = `
      <div class="popup-header">
        <span class="popup-icon">🚌</span>
        <strong>${nombre}</strong><br/>
    `;

    if (lineas.length > 0) {
      html += `<small>Líneas: ${lineas.map(l => `${l.codigo} (${l.empresa})`).join(", ")}</small>`;
    } else {
      html += `<small>Sin líneas cercanas</small>`;
    }

    html += "</div>";

    popupContent.innerHTML = html;
    popup.style.display = "block";
    overlay.setPosition(coordinate);
  }


  function ocultarPopup() {
    popup.style.display = "none";
    overlay.setPosition(undefined);
  }

  function agregarParada(coordinate) {
    const nombre = prompt("Ingrese el nombre de la parada:");
    if (!nombre || nombre.trim() === "") return;

    const [lon, lat] = ol.proj.toLonLat(coordinate);

    fetch("http://localhost:8081/transporte/api/paradas", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nombre, lat, lon }),
    })
      .then((r) => {
        if (r.ok) {
          alert("✅ Parada creada correctamente");
          const params = paradasLayer.getSource().getParams();
          params.t = Date.now();
          paradasLayer.getSource().updateParams(params);

          // Después de guardar parada exitosamente
          window.modoActual = null;
          window.actualizarBannerModo();

        } else {
          alert("❌ Error al crear parada");
        }
      })
      .catch((err) => console.error("Error guardando parada:", err));
  }
  
  // ------------------------------------------------------------------
  // --- Click en el mapa (Modificado para manejar modo 'ruteo') ---
  // ------------------------------------------------------------------
  map.on("singleclick", function (evt) {

    // 🔹 Lógica de Ruteo
    if (window.modoActual === "ruteo") {
        const [lon, lat] = ol.proj.toLonLat(evt.coordinate);
        
        if (window.puntosRuta.length === 0) {
            // Primer clic: Origen
            window.puntosRuta.push({ lon, lat });
            window.actualizarBannerModo();
            alert("Origen seleccionado. Ahora haga clic en el mapa para seleccionar el punto de DESTINO.");
        } else if (window.puntosRuta.length === 1) {
            // Segundo clic: Destino
            const origen = window.puntosRuta[0];
            const destino = { lon, lat };
            
            // 🔹 Llamar a la función para calcular y dibujar la ruta
            fetchRuta(origen, destino);
            
            // Resetear y salir del modo ruteo
            window.modoActual = null;
            window.puntosRuta = [];
            window.actualizarBannerModo();
        }
        return; // Detener el procesamiento del click si estamos en modo ruteo
    }

    // 🔹 Lógica de Parada (solo se ejecuta si modoActual es "parada")
    if (window.modoActual !== "parada") return; // ignorar si no está activo

    const viewResolution = map.getView().getResolution();
    const url = paradasLayer.getSource().getFeatureInfoUrl(
      evt.coordinate,
      viewResolution,
      "EPSG:3857",
      { INFO_FORMAT: "application/json" }
    );

    if (!url) {
      ocultarPopup();
      return;
    }

    fetch(url)
      .then((r) => r.json())
      .then((json) => {
        if (json.features && json.features.length > 0) {
          const props = json.features[0].properties;
          const idParada = props.id || props.objectid;
          const nombre = props.nombre;

          // Obtener info de líneas asociadas desde tu backend
          fetch(`http://localhost:8081/transporte/api/paradas/${idParada}/lineas`)
            .then((r) => (r.ok ? r.json() : []))
            .then((lineas) => mostrarPopupBonito(evt.coordinate, nombre, lineas))
            .catch((err) => {
              console.error("Error cargando líneas:", err);
              mostrarPopupBonito(evt.coordinate, nombre, []);
            });
        } else {
          ocultarPopup();
          agregarParada(evt.coordinate);
        }
      })
      .catch((err) => {
        console.error("Error consultando GeoServer:", err);
        ocultarPopup();
      });
  });

  map.on("pointerdown", ocultarPopup);

  // --- Botón ---
    function activarAltaParada() {
      window.modoActual = "parada";
      window.actualizarBannerModo(); // 🔹 actualiza el banner
      alert("🚌 Modo PARADA activado. Haga clic en el mapa para agregar una parada.");
    }

  window.activarAltaParada = activarAltaParada;

  // ------------------------------------------------------------------
  // --- FUNCIÓN PARA CALCULAR Y DIBUJAR LA RUTA ---
  // ------------------------------------------------------------------
  async function fetchRuta(origen, destino) {
      rutaSource.clear(); // Limpiar ruta anterior
      try {
          const payload = {
              latOrigen: origen.lat,
              lonOrigen: origen.lon,
              latDestino: destino.lat,
              lonDestino: destino.lon
          };

          const res = await fetch("http://localhost:8081/transporte/api/ruta", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(payload),
          });

          if (res.ok) {
              const data = await res.json();
              
              // El GeoJSON viene como string dentro del JSON, hay que parsearlo
              const geojsonObj = JSON.parse(data.geojson);
              
              const format = new ol.format.GeoJSON();
              // Leer las geometrías de la ruta
              const features = format.readFeatures(geojsonObj);

              // Transformar de EPSG:32721 (PostGIS) a EPSG:3857 (OpenLayers)
              features.forEach(f => f.getGeometry().transform("EPSG:32721", "EPSG:3857"));

              rutaSource.addFeatures(features);

              alert(`✅ Ruta calculada. Costo Total: ${data.costoTotal.toFixed(2)} unidades.`);
          } else {
              const error = await res.json();
              alert(`❌ Error al calcular ruta: ${error.error}`);
          }
      } catch (err) {
          console.error("Error consultando API de ruta:", err);
          alert("❌ Error de comunicación con el servidor de rutas.");
      }
  }
});
