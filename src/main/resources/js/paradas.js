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

    fetch("http://localhost:8080/transporte/api/paradas", {
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

  // --- Click en el mapa (solo si el modo es 'parada') ---
  map.on("singleclick", function (evt) {
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
          fetch(`http://localhost:8080/transporte/api/paradas/${idParada}/lineas`)
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
});
