"""Convierte la respuesta de Overpass (OSM) a un JSON compacto en metros locales.

Uso: python3 -I convert.py proyecto.maps3d.json osm.json salida.json
Toma el rectángulo y los colores del proyecto de maps3d.io.
"""
import json, math, sys

proj = json.load(open(sys.argv[1]))["params"]
osm = json.load(open(sys.argv[2]))
area = proj["areaSelected"]
lat0 = (area["ne"]["lat"] + area["sw"]["lat"]) / 2
lng0 = (area["ne"]["lng"] + area["sw"]["lng"]) / 2
M_LAT = 111_320.0
M_LNG = 111_320.0 * math.cos(math.radians(lat0))

def xy(p):  # x = este, y = sur (como el eje Z de Godot)
    return [round((p["lon"] - lng0) * M_LNG, 2), round(-(p["lat"] - lat0) * M_LAT, 2)]

ROAD_W = {"motorway": 14, "trunk": 12, "primary": 10, "secondary": 8, "tertiary": 7,
          "residential": 6, "unclassified": 5, "living_street": 5, "service": 4,
          "pedestrian": 5, "footway": 2, "cycleway": 2, "path": 1.5, "steps": 2, "track": 3}

out = {"size": [round((area["ne"]["lng"] - area["sw"]["lng"]) * M_LNG, 1),
                round((area["ne"]["lat"] - area["sw"]["lat"]) * M_LAT, 1)],
       "colors": {"ground": proj["groundColor"], "building": proj["buildings"]["color"],
                  "road": proj["roads"]["color"], "water": proj["water"]["color"], "green": "#a9c98b"},
       "buildings": [], "roads": [], "water": [], "green": [], "rail": []}

def num(s):
    try:
        return float(str(s).split()[0].replace(",", "."))
    except (ValueError, IndexError):
        return None

for e in osm["elements"]:
    if e["type"] != "way" or "geometry" not in e:
        continue
    t = e.get("tags", {})
    pts = [xy(p) for p in e["geometry"]]
    if "building" in t:
        h = num(t.get("height", ""))
        if h is None:
            lv = num(t.get("building:levels", ""))
            h = lv * 3.2 + 1 if lv else 7.0
        if pts[0] == pts[-1]:
            pts = pts[:-1]
        if len(pts) >= 3:
            out["buildings"].append({"p": pts, "h": round(h, 1), "name": t.get("name", "")})
    elif "highway" in t:
        kind = t["highway"].replace("_link", "")
        out["roads"].append({"p": pts, "w": ROAD_W.get(kind, 4), "k": kind})
    elif t.get("natural") == "water":
        out["water"].append({"p": pts[:-1]})
    elif t.get("leisure") == "park" or t.get("landuse") in ("grass", "forest", "recreation_ground"):
        out["green"].append({"p": pts[:-1]})
    elif t.get("railway") == "rail":
        out["rail"].append({"p": pts, "w": 4})

json.dump(out, open(sys.argv[3], "w"), separators=(",", ":"))
print({k: len(v) for k, v in out.items() if isinstance(v, list)}, "tamaño:", out["size"])
