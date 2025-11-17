console.log("main.js cargado correctamente");

// ======================================================
// MAPA BASE
// ======================================================
const map = new ol.Map({
  target: "map",
  layers: [new ol.layer.Tile({ source: new ol.source.OSM() })],
  view: new ol.View({
    center: ol.proj.fromLonLat([-56.1645, -34.9011]),
    zoom: 13
  })
});

// ======================================================
// CONFIG
// ======================================================
const GEOSERVER_WFS = "http://localhost:8080/geoserver/transporte/ows";
const NAMESPACE = "transporte";
const PARADAS_API = "http://localhost:8081/api/paradas";
const RUTAS_API = "http://localhost:8081/api/rutas";

const geojsonFormat = new ol.format.GeoJSON();
const wktFormat = new ol.format.WKT();

// ======================================================
// PARADAS WFS
// ======================================================
const sourceParadas = new ol.source.Vector({
  format: geojsonFormat,
  loader: (extent, resolution, projection, success, failure) => {
    const viewExtent = ol.proj.transformExtent(extent, projection.getCode(), "EPSG:4326");
    const url =
      `${GEOSERVER_WFS}?service=WFS&version=2.0.0&request=GetFeature` +
      `&typeNames=${NAMESPACE}:paradas` +
      `&outputFormat=application/json&srsName=EPSG:4326` +
      `&bbox=${viewExtent.join(",")},EPSG:4326`;

    fetch(url)
      .then(r => r.json())
      .then(data => {
        const feats = geojsonFormat.readFeatures(data, {
          featureProjection: "EPSG:3857"
        });
        sourceParadas.clear();
        sourceParadas.addFeatures(feats);
        success();
      })
      .catch(err => {
        console.error("Error WFS paradas:", err);
        failure();
      });
  },
  strategy: ol.loadingstrategy.bbox
});

const layerParadas = new ol.layer.Vector({
  source: sourceParadas,
  style: new ol.style.Style({
    image: new ol.style.Circle({
      radius: 7,
      fill: new ol.style.Fill({ color: "red" }),
      stroke: new ol.style.Stroke({ color: "#fff", width: 2 })
    })
  })
});
map.addLayer(layerParadas);

// ======================================================
// RUTAS WFS
// ======================================================
const sourceRutas = new ol.source.Vector({
  format: geojsonFormat,
  loader: (extent, resolution, projection, success, failure) => {
    const viewExtent = ol.proj.transformExtent(extent, projection.getCode(), "EPSG:4326");
    const url =
      `${GEOSERVER_WFS}?service=WFS&version=2.0.0&request=GetFeature` +
      `&typeNames=${NAMESPACE}:rutas_resultado` +
      `&outputFormat=application/json&srsName=EPSG:4326` +
      `&bbox=${viewExtent.join(",")},EPSG:4326`;

    fetch(url)
      .then(r => r.json())
      .then(data => {
        const feats = geojsonFormat.readFeatures(data, {
          featureProjection: "EPSG:3857"
        });
        sourceRutas.clear();
        sourceRutas.addFeatures(feats);
        success();
      })
      .catch(err => {
        console.error("Error WFS rutas:", err);
        failure();
      });
  },
  strategy: ol.loadingstrategy.bbox
});

const layerRutas = new ol.layer.Vector({
  source: sourceRutas,
  style: feature => [
    new ol.style.Style({
      stroke: new ol.style.Stroke({ color: "blue", width: 4 })
    }),
    new ol.style.Style({
      image: new ol.style.Circle({
        radius: 2,
        fill: new ol.style.Fill({ color: "white" }),
        stroke: new ol.style.Stroke({ color: "blue", width: 2 })
      }),
      geometry: feature => {
        const geom = feature.getGeometry();
        if (geom.getType() === "MultiLineString") {
          return new ol.geom.MultiPoint(geom.getCoordinates().flat());
        }
        return null;
      }
    })
  ]
});
map.addLayer(layerRutas);

// ======================================================
// POPUP
// ======================================================
const popup = document.getElementById("popup");
const popupContent = document.getElementById("popup-content");
const overlay = new ol.Overlay({
  element: popup,
  autoPan: true,
  positioning: "bottom-center",
  offset: [0, -10]
});
map.addOverlay(overlay);

// ======================================================
// HELPERS
// ======================================================
function fid(f) {
  const id = f.getId();
  if (id) {
    const last = id.split(".").pop();
    if (!isNaN(last)) return parseInt(last);
  }
  return f.get("id");
}

// ======================================================
// API PARADAS
// ======================================================
function crearParada(lon, lat, nombre) {
  return fetch(PARADAS_API, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ nombre, lon, lat })
  }).then(r => r.json());
}

function eliminarParada(id) {
  return fetch(`${PARADAS_API}/${id}`, { method: "DELETE" }).then(r => r.json());
}

function actualizarParada(id, nombre, lon, lat) {
  return fetch(`${PARADAS_API}/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id, nombre, lon, lat })
  }).then(r => r.json());
}

// ======================================================
// PARADAS: SELECT + MOVE + MODIFY
// ======================================================
const selectParadas = new ol.interaction.Select({ layers: [layerParadas] });
const translate = new ol.interaction.Translate({ features: selectParadas.getFeatures() });
const modify = new ol.interaction.Modify({ features: selectParadas.getFeatures() });

map.addInteraction(selectParadas);
map.addInteraction(translate);
map.addInteraction(modify);

// mover parada
translate.on("translateend", e => {
  const f = e.features.item(0);
  const id = fid(f);
  const [lon, lat] = ol.proj.toLonLat(f.getGeometry().getCoordinates());
  actualizarParada(id, null, lon, lat).then(() => sourceParadas.refresh());
});

// ======================================================
// EDITAR RUTAS (tu versión buena)
// ======================================================
const selectRutas = new ol.interaction.Select({
  layers: [layerRutas],
  hitTolerance: 5
});
selectRutas.setActive(false);
map.addInteraction(selectRutas);

const modifyRutas = new ol.interaction.Modify({
  source: sourceRutas,
  deleteCondition: e => ol.events.condition.shiftKeyOnly(e),
  insertVertexCondition: () => true
});
modifyRutas.setActive(false);
map.addInteraction(modifyRutas);

// =======================
// AGREGAR PERSISTENCIA
// =======================
modifyRutas.on("modifyend", event => {
  const f = event.features.item(0);
  if (!f) return;

  const id = fid(f);

  const geom4326 = f.getGeometry().clone()
    .transform("EPSG:3857", "EPSG:4326");

  const wkt = wktFormat.writeGeometry(geom4326);

  console.log("Guardando ruta WKT:", wkt);

  fetch(`${RUTAS_API}/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id, wkt })
  })
    .then(r => r.json())
    .then(r => {
      console.log("Guardado:", r);
      alert("Ruta guardada ✔");
      sourceRutas.refresh();
    })
    .catch(err => console.error("Error:", err));
});

// Botón de activar/desactivar edición
document.getElementById("btnEditarRuta").onclick = () => {
  const on = !modifyRutas.getActive();
  selectRutas.setActive(on);
  modifyRutas.setActive(on);

  alert(
    on
      ? "Modo EDITAR RUTA ACTIVADO.\nMover vértices, agregar (CTRL+clic) y borrar (SHIFT+clic)."
      : "Modo EDITAR RUTA DESACTIVADO."
  );
};

// ======================================================
// CREAR PARADA
// ======================================================
let modoCrear = false;
document.getElementById("btnCrearParada").onclick = () => {
  modoCrear = true;
  alert("Click en el mapa para agregar una parada.");
};

map.on("click", evt => {
  if (!modoCrear) return;

  const [lon, lat] = ol.proj.toLonLat(evt.coordinate);
  const nombre = prompt("Nombre de la parada:");

  if (nombre) {
    crearParada(lon, lat, nombre).then(() => sourceParadas.refresh());
  }
  modoCrear = false;
});

// ======================================================
// ELIMINAR PARADA
// ======================================================
let modoEliminar = false;
document.getElementById("btnEliminarParada").onclick = () => {
  modoEliminar = true;
  alert("Click en una parada para eliminarla.");
};

map.on("singleclick", evt => {
  if (!modoEliminar) return;

  const f = map.forEachFeatureAtPixel(evt.pixel, ft =>
    layerParadas.getSource().hasFeature(ft) ? ft : null
  );

  if (f) {
    const id = fid(f);
    if (confirm("¿Eliminar parada " + id + "?")) {
      eliminarParada(id).then(() => sourceParadas.refresh());
    }
  }

  modoEliminar = false;
});

// ======================================================
// REFRESCAR
// ======================================================
document.getElementById("btnRefrescar").onclick = () => {
  sourceParadas.refresh();
  sourceRutas.refresh();
};

// ======================================================
// CARGA INICIAL
// ======================================================
sourceParadas.refresh();
sourceRutas.refresh();
