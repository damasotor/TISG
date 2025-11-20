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

// INTERACCIONES PARA RUTAS (editar geometría de la línea)
const selectRuta = new ol.interaction.Select({
  layers: [layerRuta],
  hitTolerance: 6
});

const modifyRuta = new ol.interaction.Modify({
  features: selectRuta.getFeatures()
});

// Al principio desactivadas: se activan sólo cuando el usuario toca el botón "Modificar ruta"
selectRuta.setActive(false);
modifyRuta.setActive(false);

map.addInteraction(selectRuta);
map.addInteraction(modifyRuta);


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
let modoModificarRuta = false; 

// ESTADO DE RUTA ACTUAL
let rutaActualLonLat = null;  // array de [lon, lat] de la ruta actual
let rutaIdInicio = null;
let rutaIdFin = null;

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

document.getElementById("btnBuscarLineasEmpresa").onclick = () => {
  const nombre = prompt("Nombre de la empresa (ej: CUTCSA):");
  if (!nombre) return;
  buscarLineasPorEmpresa(nombre);
};


// Botón para MODIFICAR RUTA (mover nodos de la línea ya calculada)
const btnModificarRuta = document.getElementById("btnModificarRuta");
if (btnModificarRuta) {
  btnModificarRuta.onclick = () => {
    if (!rutaActualLonLat || !rutaActualLonLat.length) {
      alert("No hay ninguna ruta dibujada para modificar.");
      return;
    }

    modoModificarRuta = !modoModificarRuta;
    selectRuta.setActive(modoModificarRuta);
    modifyRuta.setActive(modoModificarRuta);

    alert(
      modoModificarRuta
        ? "Modo MODIFICAR RUTA activado: hacé clic en la línea y arrastrá un vértice."
        : "Modo MODIFICAR RUTA desactivado."
    );
  };
}


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

        <div id="popupLineas" style="margin-top:8px; font-size:12px; color:#333;">
            <em>Cargando líneas asociadas...</em>
        </div>

        <div style="margin-top:8px;">
            <button id="popupEditar">Editar</button>
            <button id="popupEliminar2">Eliminar</button>
        </div>
   `;


    overlay.setPosition(coord);
    popup.style.display = "block";

    setTimeout(() => {
        // BOTÓN EDITAR
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

        // BOTÓN ELIMINAR
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

        // 🔹 NUEVO: CONTENEDOR PARA MOSTRAR LÍNEAS
        const divLineas = document.createElement("div");
        divLineas.id = "popupLineas";
        divLineas.style.marginTop = "8px";
        divLineas.innerHTML = "<em>Cargando líneas asociadas...</em>";
        popupContent.appendChild(divLineas);
    
        // 🔹 NUEVO: Fetch a /api/paradaLineas
        fetch(`http://localhost:8080/transporte-1.0/api/paradaLineas?paradaId=${paradaId}`)
            .then(r => r.json())
            .then(data => {
                console.log("paradaLineas:", data);
    
                if (!data.success) {
                    divLineas.innerHTML = `<span style="color:red;">Error: ${data.error || "No se pudieron cargar las líneas"}</span>`;
                    return;
                }

                const lineas = data.lineas || [];

                if (lineas.length === 0) {
                    divLineas.innerHTML = `<em>No hay líneas asociadas a esta parada.</em>`;
                    return;
                }

                let html = "<u>Líneas que pasan por aquí:</u><br>";
                lineas.forEach(l => {
                const horarios = (l.horarios || []).join(", ");
                const estado = l.habilitada ? "habilitada" : "deshabilitada";

                html += `
    • ${l.codigo} <small>(${estado})</small>
      <button class="btnVerLinea" data-linea="${l.linea_id}" style="margin-left:5px; font-size:10px;">
        Ver en mapa
      </button>
`               ;

                if (horarios) {
                    html += `<br>&nbsp;&nbsp;Horarios: ${horarios}`;
                }
                html += "<br>";
            });

            divLineas.innerHTML = html;
    // Delegar click: ver geometría de línea
    document.querySelectorAll(".btnVerLinea").forEach(btn => {
        btn.onclick = () => {
            const idLinea = btn.dataset.linea;

            fetch(`http://localhost:8080/transporte-1.0/api/lineaGeom?idLinea=${idLinea}`)
                .then(r => r.json())
                .then(data => {
                    if (!data.success) {
                        alert("Error: " + data.error);
                        return;
                    }

                    const geom = data.geom;
                    if (!geom || !geom.coordinates) {
                        alert("Geom inválida");
                        return;
                    }

                    let coords = geom.coordinates;

                    // MultiLineString → quedarse solo con primer tramo
                    if (Array.isArray(coords[0][0])) {
                        console.log("MultiLineString detectado");
                        coords = coords[0];
                    }

                    rutaActualLonLat = coords.map(c => [c[0], c[1]]);
    
                    // Limpiar capa de ruta actual y dibujar
                    sourceRuta.clear();
                    dibujarRuta(rutaActualLonLat);
    
                    alert("Línea dibujada en el mapa.");
                })
                .catch(err => {
                    console.error(err);
                    alert("Error cargando la geometría de la línea");
                });
            };
        });

        })
        .catch(err => {
            console.error("Error cargando líneas de parada:", err);
            divLineas.innerHTML = `<span style="color:red;">Error cargando líneas.</span>`;
        });

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
// Cuando se termina de modificar la geometría de la RUTA
modifyRuta.on("modifyend", (evt) => {
  const features = evt.features.getArray();
  if (!features.length) return;

  const geom = features[0].getGeometry();
  if (!(geom instanceof ol.geom.LineString)) {
    console.warn("[modifyRuta] La geometría no es una LineString.");
    return;
  }

  // Coord en proyección del mapa → pasamos a lon/lat
  const coords3857 = geom.getCoordinates();
  const coordsLonLat = coords3857.map(c => ol.proj.toLonLat(c));

  if (!rutaActualLonLat || rutaActualLonLat.length !== coordsLonLat.length) {
    // Algo raro: cambió la cantidad de vértices
    rutaActualLonLat = coordsLonLat;
    console.warn("[modifyRuta] Cambio de cantidad de vértices, se actualiza copia local pero no se recalcula.");
    return;
  }

  // Detectar qué vértice se movió
  const EPS = 1e-5;
  let movedIndex = -1;

  for (let i = 0; i < coordsLonLat.length; i++) {
    const [lon0, lat0] = rutaActualLonLat[i];
    const [lon1, lat1] = coordsLonLat[i];
    const d = Math.hypot(lon1 - lon0, lat1 - lat0);
    if (d > EPS) {
      movedIndex = i;
      break;
    }
  }

  if (movedIndex === -1) {
    console.log("[modifyRuta] No se detectó vértice movido.");
    return;
  }

  const [viaLon, viaLat] = coordsLonLat[movedIndex];
  console.log("[modifyRuta] Vértice movido en índice", movedIndex, "a", viaLon, viaLat);

  // Actualizamos la copia local
  rutaActualLonLat = coordsLonLat;

  // Pedir recálculo al backend usando este punto como "via"
  recalcularRutaConVia(viaLon, viaLat);
});



function crearRuta() {
  if (!paradaInicio || !paradaFin) {
    alert("Seleccioná primero la parada de inicio y luego la de fin.");
    return;
  }
  sourceRuta.clear();

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

      // Guardar estado de la ruta actual
      rutaIdInicio = idInicio;
      rutaIdFin = idFin;

      // Aplanar el MultiLineString → array de [lon,lat]
      const coords = data.coordinates.flat();
      rutaActualLonLat = coords.map(c => [c[0], c[1]]);

      // Dibujar
      dibujarRuta(rutaActualLonLat);

      alert("Ruta creada exitosamente");

      // Reset de selección de paradas (pero NO de rutaIdInicio/Fin)
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
    sourceRuta.clear(true);
    const feature = new ol.Feature({ geometry: lineString });
    sourceRuta.addFeature(feature);

    map.getView().fit(extent, {
        padding: [50, 50, 50, 50],
        duration: 800
    });

    console.log("[dibujarRuta] Ruta dibujada correctamente.");
}

document.getElementById("btnGuardarLinea").addEventListener("click", guardarLinea);

function guardarLinea() {
  if (!sourceRuta.getFeatures().length) {
    alert("No hay ruta para guardar.");
    return;
  }

  const feature = sourceRuta.getFeatures()[0];
  const geom    = feature.getGeometry();

  if (!(geom instanceof ol.geom.LineString)) {
    alert("La geometría de la ruta no es una LineString.");
    return;
  }

  const coords3857  = geom.getCoordinates();
  const coordsLonLat = coords3857.map(c => ol.proj.toLonLat(c));

  const geomJson = {
    type: "LineString",
    coordinates: coordsLonLat
  };

  const codigo  = prompt("Código de la línea:");
  if (!codigo) {
    alert("Debe indicar un código de línea.");
    return;
  }

  const origen  = prompt("Origen de la línea:");
  if (!origen) {
    alert("Debe indicar un origen.");
    return;
  }

  const destino = prompt("Destino de la línea:");
  if (!destino) {
    alert("Debe indicar un destino.");
    return;
  }

  const empresa = prompt("Empresa (tal como figura en la tabla empresas, ej: CUTCSA):");
  if (!empresa) {
    alert("Debe indicar una empresa.");
    return;
  }

  const formData = new URLSearchParams();
  formData.append("codigo",  codigo.trim());
  formData.append("origen",  origen.trim());
  formData.append("destino", destino.trim());
  formData.append("empresa", empresa.trim());  // 👈 ahora desde el prompt
  formData.append("geom",    JSON.stringify(geomJson));

  fetch("/transporte-1.0/api/registrarLinea", {
    method: "POST",
    body: formData
  })
    .then(r => r.json())
    .then(res => {
      console.log(res);
      if (res.success) {
        alert("Línea registrada con ID: " + res.linea_id);
      } else {
        alert("Error: " + res.error);
      }
    })
    .catch(err => {
      console.error("Error registrando línea:", err);
      alert("Error registrando línea");
    });
}




function recalcularRutaConVia(viaLon, viaLat) {
  if (rutaIdInicio == null || rutaIdFin == null) {
    console.warn("[recalcularRutaConVia] No hay id de inicio/fin guardados.");
    return;
  }

  const url =
    `http://localhost:8080/transporte-1.0/api/nuevaRutaConVia` +
    `?idInicio=${rutaIdInicio}&idFin=${rutaIdFin}` +
    `&viaLon=${viaLon}&viaLat=${viaLat}`;

  fetch(url)
    .then(r => r.json())
    .then(data => {
      console.log("Ruta recalculada:", data);

      if (!data || !data.coordinates) {
        alert("El servidor no devolvió una ruta válida al recalcular.");
        return;
      }

      let coords;
      if (Array.isArray(data.coordinates[0][0])) {
        console.log("[recalcularRutaConVia] MultiLineString detectado, usando sólo el primer tramo.");
        coords = data.coordinates[0];
      } else {
        coords = data.coordinates;
      }

      rutaActualLonLat = coords.map(c => [c[0], c[1]]);

      dibujarRuta(rutaActualLonLat);
      alert("Ruta recalculada con el nuevo punto intermedio.");
    })
    .catch(err => {
      console.error(err);
      alert("Error recalculando la ruta.");
    });
}

function buscarLineasPorEmpresa(nombreEmpresa) {
  const url = `http://localhost:8080/transporte-1.0/api/lineasEmpresa?empresa=${encodeURIComponent(nombreEmpresa)}`;

  fetch(url)
    .then(r => r.json())
    .then(data => {
      console.log("lineasEmpresa:", data);

      if (!data.success) {
        alert("Error: " + (data.error || "No se pudieron obtener las líneas"));
        return;
      }

      const lineas = data.lineas || [];
      if (!lineas.length) {
        alert(`La empresa ${nombreEmpresa} no tiene líneas registradas.`);
        return;
      }

      let msg = `Líneas de ${nombreEmpresa}:\n\n`;
      lineas.forEach(l => {
        msg += `• ${l.codigo} — ${l.origen} → ${l.destino}\n`;
      });

      alert(msg);
    })
    .catch(err => {
      console.error("Error buscando líneas por empresa:", err);
      alert("Error buscando líneas por empresa.");
    });
}

