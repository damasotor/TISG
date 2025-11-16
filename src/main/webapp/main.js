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

document.getElementById("btnModoModificar").onclick = () => {
  modoModificar = !modoModificar;
  modoParada = modoEliminar = false;
  alert(modoModificar ? "Modo MODIFICAR activado" : "Modo MODIFICAR desactivado");
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

// CLICK CREAR
map.on("click", evt => {
  if (!modoParada) return;

  const [lon, lat] = ol.proj.toLonLat(evt.coordinate);
  const nombre = prompt("Nombre de la parada:");
  if (!nombre) {
    modoParada = false;
    return;
  }

  crearParadaRemote(lon, lat, nombre)
    .then(r => {
      alert(r.message || JSON.stringify(r));
      sourceParadas.refresh();
    })
    .catch(err => {
      console.error(err);
      alert("Error creando parada.");
    });

  modoParada = false;
});

// CLICK POPUP + ELIMINAR
map.on("singleclick", evt => {
  const f = map.forEachFeatureAtPixel(evt.pixel, (ft, layer) =>
    layer === vectorLayerParadas ? ft : null
  );

  if (modoEliminar && f) {
    const id = getFeatureId(f);
    if (!confirm("Eliminar parada " + id + "?")) return;

    eliminarParadaRemote(id).then(r => {
      alert(r.message || JSON.stringify(r));
      sourceParadas.refresh();
    });

    modoEliminar = false;
    return;
  }

  if (!f) {
    popup.style.display = "none";
    overlay.setPosition(undefined);
    return;
  }

  const id = getFeatureId(f);
  const nombre = f.get("nombre") || "";
  const coord = f.getGeometry().getCoordinates();

  popupContent.innerHTML = `
    <div><strong>${nombre}</strong></div>
    <div>ID: ${id}</div>
    <div style="margin-top:8px;">
      <button id="popupEditar">Editar</button>
      <button id="popupEliminar">Eliminar</button>
    </div>
  `;

  overlay.setPosition(coord);
  popup.style.display = "block";

  setTimeout(() => {
    document.getElementById("popupEditar").onclick = () => {
      const nuevo = prompt("Nuevo nombre:", nombre);
      if (nuevo === null) return;

      actualizarParadaRemote(id, nuevo).then(r => {
        alert(r.message || JSON.stringify(r));
        popup.style.display = "none";
        sourceParadas.refresh();
      });
    };

    document.getElementById("popupEliminar").onclick = () => {
      if (!confirm("Eliminar parada " + id + "?")) return;

      eliminarParadaRemote(id).then(r => {
        alert(r.message || JSON.stringify(r));
        popup.style.display = "none";
        sourceParadas.refresh();
      });
    };
  }, 20);
});
// SELECCIONAR DOS PARADAS PARA CREAR LA RUTA
map.on("singleclick", function(evt) {
  const f = map.forEachFeatureAtPixel(evt.pixel, (ft, layer) =>
    layer === vectorLayerParadas ? ft : null
  );

  if (!f) return;

  if (!paradaInicio) {
    paradaInicio = f;
    alert("Parada de inicio seleccionada: " + getFeatureId(f));
  } else if (!paradaFin) {
    paradaFin = f;
    alert("Parada de fin seleccionada: " + getFeatureId(f));
  }
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

  const url = `http://localhost:8081/api/nuevaRuta?idInicio=${idInicio}&idFin=${idFin}`;

  fetch(url)
    .then(r => r.json())
    .then(data => {
      console.log("Ruta recibida:", data);

      if (!data || !data.coordinates) {
        alert("El servidor no devolvió una ruta válida");
        return;
      }

      // borrar rutas anteriores
      sourceRuta.clear();

      const geom = new ol.geom.LineString(
        data.coordinates.map(c => ol.proj.fromLonLat(c))
      );

      const feat = new ol.Feature({ geometry: geom });
      sourceRuta.addFeature(feat);

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


