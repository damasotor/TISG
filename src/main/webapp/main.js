// main.js transporte-Serafín
console.log("main.js cargado correctamente");

// MAPA
const map = new ol.Map({
  target: "map",
  layers: [new ol.layer.Tile({ source: new ol.source.OSM() })],
  view: new ol.View({
    center: ol.proj.fromLonLat([-56.1645, -34.9011]),
    zoom: 13
  })
});

// CONFIG
const GEOSERVER_WFS = "http://localhost:9999/geoserver/transporte/ows";
const NAMESPACE = "transporte";
const LAYER_NAME = "paradas";
const PARADAS_API_BASE = "http://localhost:8080/transporte-1.0/api/nuevaParada";


// FORMATO GEOJSON
const geojsonFormat = new ol.format.GeoJSON();

// FUENTE WFS
const sourceParadas = new ol.source.Vector({
  format: geojsonFormat,
  loader: (extent, resolution, projection, success, failure) => {
    const viewExtent = ol.proj.transformExtent(extent, projection.getCode(), "EPSG:4326");

    const url =
  `${GEOSERVER_WFS}?service=WFS&version=2.0.0&request=GetFeature` +
  `&typeNames=${NAMESPACE}:${LAYER_NAME}` +
  `&outputFormat=application/json&srsName=EPSG:4326` +
  `&bbox=${viewExtent.join(",")},EPSG:4326`;

    fetch(url)
      .then(r => r.json())
      .then(data => {
        const feats = geojsonFormat.readFeatures(data, {
          featureProjection: "EPSG:3857"
        });
        sourceParadas.clear(true);
        sourceParadas.addFeatures(feats);
        success(feats);
      })
      .catch(err => {
        console.error("Error cargando WFS:", err);
        failure();
      });
  },
  strategy: ol.loadingstrategy.bbox
});

// CAPA
const vectorLayerParadas = new ol.layer.Vector({
  source: sourceParadas,
  style: f =>
    new ol.style.Style({
      image: new ol.style.Circle({
        radius: 7,
        fill: new ol.style.Fill({ color: "red" }),
        stroke: new ol.style.Stroke({ color: "#fff", width: 2 })
      })
    })
});
map.addLayer(vectorLayerParadas);
// CAPA PARA RUTAS
const sourceRuta = new ol.source.Vector();
const layerRuta = new ol.layer.Vector({
  source: sourceRuta,
  style: new ol.style.Style({
    stroke: new ol.style.Stroke({
      color: "blue",
      width: 4
    })
  })
});
map.addLayer(layerRuta);


// INTERACCIONES
const select = new ol.interaction.Select({ layers: [vectorLayerParadas], hitTolerance: 6 });
const modify = new ol.interaction.Modify({ features: select.getFeatures() });
const translate = new ol.interaction.Translate({ features: select.getFeatures() });
map.addInteraction(select);
map.addInteraction(modify);
map.addInteraction(translate);

// MODOS
let modoParada = false;
let modoEliminar = false;
let modoModificar = false;
let paradaInicio = null;
let paradaFin = null;

// POPUP
const popup = document.getElementById("popup");
const popupContent = document.getElementById("popup-content");
const overlay = new ol.Overlay({
  element: popup,
  autoPan: true,
  positioning: "bottom-center",
  offset: [0, -10]
});
map.addOverlay(overlay);

// UI
document.getElementById("btnCrearParada").onclick = () => {
  modoParada = true;
  modoEliminar = modoModificar = false;
  alert("Modo CREAR: clic en el mapa para agregar una parada.");
};

document.getElementById("btnModoEliminar").onclick = () => {
  modoEliminar = !modoEliminar;
  modoParada = modoModificar = false;
  alert(modoEliminar ? "Modo ELIMINAR activado" : "Modo ELIMINAR desactivado");
};

document.getElementById("btnRefrescar").onclick = () => {
  sourceParadas.clear();
  sourceParadas.refresh();
};

// HELPERS
function getFeatureId(f) {
  const fid = f.getId();
  if (fid) {
    const parts = fid.split(".");
    const last = parts[parts.length - 1];
    if (!isNaN(last)) return parseInt(last);
  }
  return parseInt(f.get("gid") || f.get("id") || f.get("objectid"));
}

function getFeatureById(id) {
  return sourceParadas.getFeatures().find(f => getFeatureId(f) === id);
}

// API
function crearParadaRemote(lon, lat, nombre) {
  return fetch(PARADAS_API_BASE, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ nombre, lon, lat })
  }).then(r => r.json());
}

function eliminarParadaRemote(id) {
  return fetch(`${PARADAS_API_BASE}/${id}`, { method: "DELETE" }).then(r => r.json());
}

function actualizarParadaRemote(id, nombre, lon, lat) {
  const f = getFeatureById(id);

  if (!f) {
    console.error("Feature no encontrada para id", id);
    return Promise.reject("Feature no encontrada");
  }

  if (nombre === undefined || nombre === null) {
    nombre = f.get("nombre");
  }

  if (lon === undefined || lat === undefined) {
    const coords = ol.proj.toLonLat(f.getGeometry().getCoordinates());
    lon = coords[0];
    lat = coords[1];
  }

  return fetch(`${PARADAS_API_BASE}/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id, nombre, lon, lat })
  }).then(r => r.json());
}

//handler de eventos

map.on("singleclick", function(evt) {

    // 1) MODO CREAR PARADA
    if (modoParada) {
        const [lon, lat] = ol.proj.toLonLat(evt.coordinate);
        const nombre = prompt("Nombre de la parada:");
        if (!nombre) {
            modoParada = false;
            return;
        }

        crearParadaRemote(lon, lat, nombre)
            .then(r => {
                alert(r.message || "Parada creada");
                sourceParadas.refresh();
            })
            .catch(err => {
                console.error(err);
                alert("Error creando parada");
            });

        modoParada = false;
        return;
    }

    // 2) DETECTAR FEATURE CLICKEADA
    const f = map.forEachFeatureAtPixel(
        evt.pixel,
        (ft, layer) => (layer === vectorLayerParadas ? ft : null)
    );

    // Si el click NO es sobre una parada:
    if (!f) {
        popup.style.display = "none";
        overlay.setPosition(undefined);
        return;
    }

    // <-- AQUÍ definimos el id correctamente
    const paradaId = getFeatureId(f);
    const nombre = f.get("nombre") || "";

    // 3) MODO ELIMINAR
    if (modoEliminar) {
        if (!confirm("¿Eliminar parada " + paradaId + "?")) {
            modoEliminar = false;
            return;
        }

        eliminarParadaRemote(paradaId).then(r => {
            alert(r.message || "Eliminada");
            sourceParadas.refresh();
        }).catch(err => {
            console.error("Error eliminando:", err);
            alert("Error eliminando parada");
        }).finally(() => {
            modoEliminar = false;
        });

        return;
    }

    // 4) SELECCIÓN DE RUTA (solo si NO estamos en modo modificar)
    if (!modoModificar) {
        if (!paradaInicio) {
            paradaInicio = f;
            alert("Parada de inicio seleccionada: " + paradaId);
            return;
        } else if (!paradaFin) {
            paradaFin = f;
            alert("Parada de fin seleccionada: " + paradaId);
            return;
        }
    }

    // 5) MOSTRAR POPUP (editar / eliminar)
    const coord = f.getGeometry().getCoordinates();

    popupContent.innerHTML = `
        <div><strong>${nombre}</strong></div>
        <div>ID: ${paradaId}</div>
        <div style="margin-top:8px;">
            <button id="popupEditar">Editar</button>
            <button id="popupEliminar2">Eliminar</button>
        </div>
    `;

    overlay.setPosition(coord);
    popup.style.display = "block";

    setTimeout(() => {

        document.getElementById("popupEditar").onclick = () => {
            const nuevo = prompt("Nuevo nombre:", nombre);
            if (nuevo === null) return;

            actualizarParadaRemote(paradaId, nuevo)
                .then(r => {
                    alert(r.message || "Actualizado");
                    popup.style.display = "none";
                    sourceParadas.refresh();
                })
                .catch(err => {
                    console.error("Error actualizando:", err);
                    alert("Error actualizando parada");
                });
        };

        document.getElementById("popupEliminar2").onclick = () => {
            if (!confirm("¿Eliminar parada " + paradaId + "?")) return;

            eliminarParadaRemote(paradaId).then(r => {
                alert(r.message || "Eliminada");
                popup.style.display = "none";
                sourceParadas.refresh();
            }).catch(err => {
                console.error("Error eliminando desde popup:", err);
                alert("Error eliminando parada");
            });
        };

    }, 10);
});



// MANEJAR MODIFICACIÓN O TRASLADO
function manejarEdicion(ev) {
  const f = ev.features.item(0) || ev.features.getArray()[0];
  const id = getFeatureId(f);
  const [lon, lat] = ol.proj.toLonLat(f.getGeometry().getCoordinates());

  actualizarParadaRemote(id, undefined, lon, lat).then(() => {
    sourceParadas.refresh();
  });
}

translate.on("translateend", manejarEdicion);
modify.on("modifyend", manejarEdicion);

// CARGA INICIAL
sourceParadas.refresh();
function crearRuta() {
  if (!paradaInicio || !paradaFin) {
    alert("Seleccioná primero la parada de inicio y luego la de fin.");
    return;
  }

  const idInicio = getFeatureId(paradaInicio);
  const idFin = getFeatureId(paradaFin);

  const url = `http://localhost:8080/transporte-1.0/api/nuevaRuta?idInicio=${idInicio}&idFin=${idFin}`;

  fetch(url)
    .then(r => r.json())
    .then(data => {
      console.log("Ruta recibida:", data);

      if (!data || !data.coordinates) {
        alert("El servidor no devolvió una ruta válida");
        return;
      }

      dibujarRuta( data.coordinates.flat() );

      alert("Ruta creada exitosamente");

      // reset
      paradaInicio = null;
      paradaFin = null;
    })
    .catch(err => {
      console.error(err);
      alert("Error creando ruta.");
    });
}

/**
 * Dibuja la ruta en el mapa.
 * @param {Array<Array<number>>} coordinates - Un array de pares [longitud, latitud].
 */
function dibujarRuta(coordinates) {
    console.log(`[dibujarRuta] Recibidas ${coordinates.length} coordenadas.`);

    if (coordinates.length < 2) {
        console.warn("[dibujarRuta] Se necesitan al menos 2 puntos.");
        return;
    }

    // Log coordenadas crudas
    console.log("[dibujarRuta] Coordenadas crudas:", coordinates);

    // Limpiar rutas anteriores
    sourceRuta.clear();

    // Validación de formato
    const coords3857 = [];
    for (let i = 0; i < coordinates.length; i++) {
        const c = coordinates[i];

        if (!Array.isArray(c) || c.length !== 2) {
            console.error(`[dibujarRuta] Coordenada inválida índice ${i}:`, c);
            return;
        }

        const [lon, lat] = c;

        if (isNaN(lon) || isNaN(lat)) {
            console.error(`[dibujarRuta] Coordenada con NaN índice ${i}:`, c);
            return;
        }

        if (Math.abs(lon) > 200 || Math.abs(lat) > 100) {
            console.error(`[dibujarRuta] Coordenada fuera de rango índice ${i}:`, c);
            return;
        }

        const transformed = ol.proj.fromLonLat([lon, lat]);
        coords3857.push(transformed);
    }

    console.log("[dibujarRuta] Coordenadas transformadas:", coords3857);

    const lineString = new ol.geom.LineString(coords3857);

    // CHEQUEAR EXTENT
    const extent = lineString.getExtent();
    console.log("[dibujarRuta] Extent:", extent);

    if (extent[0] === extent[2] && extent[1] === extent[3]) {
        console.error("[dibujarRuta] EXTENT VACÍO — las coordenadas transformadas coinciden.");
        return;
    }

    const feature = new ol.Feature({ geometry: lineString });
    sourceRuta.addFeature(feature);

    map.getView().fit(extent, {
        padding: [50, 50, 50, 50],
        duration: 800
    });

    console.log("[dibujarRuta] Ruta dibujada correctamente.");
}


