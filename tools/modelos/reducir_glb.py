#!/usr/bin/env python3
"""Reduce las texturas de un modelo .glb (p. ej. de Meshy) sin tocar la malla.

Uso:
  tools/modelos/reducir_glb.py ORIGEN.glb [DESTINO.glb] [--max 1024] [--calidad 88] [--altura 1.9]

- Cada imagen se reduce a `--max` píxeles de lado como mucho (manteniendo la
  proporción). Las que no tienen transparencia pasan a JPG (pesan mucho menos);
  las que sí, siguen en PNG.
- `--altura`: escala el modelo para que mida eso en metros (algunos salen de
  Meshy en centímetros: 0,02 m de alto).
- Sin DESTINO, se guarda en assets/modelos/<nombre>.glb del proyecto.
- Usa `sips` (viene con macOS). No necesita nada instalado.
"""
import argparse
import json
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read_glb(path):
    data = path.read_bytes()
    magic, version, _ = struct.unpack("<4sII", data[:12])
    if magic != b"glTF" or version != 2:
        sys.exit(f"{path} no es un .glb (glTF 2)")
    gltf, binary, pos = None, b"", 12
    while pos < len(data):
        length, kind = struct.unpack("<II", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if kind == JSON_CHUNK:
            gltf = json.loads(chunk)
        elif kind == BIN_CHUNK:
            binary = chunk
        pos += 8 + length
    return gltf, binary


def write_glb(path, gltf, binary):
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    binary += b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<II", len(js), JSON_CHUNK) + js)
        f.write(struct.pack("<II", len(binary), BIN_CHUNK) + binary)


def sips_info(path):
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(path)],
                         capture_output=True, text=True, check=True).stdout
    info = dict(line.strip().split(": ", 1) for line in out.splitlines()[1:] if ": " in line)
    return int(info["pixelWidth"]), int(info["pixelHeight"]), info.get("hasAlpha") == "yes"


def shrink(img_bytes, mime, max_side, quality, tmp):
    src = tmp / ("in.png" if mime == "image/png" else "in.jpg")
    src.write_bytes(img_bytes)
    w, h, alpha = sips_info(src)
    as_jpg = not alpha
    dst = tmp / ("out.jpg" if as_jpg else "out.png")
    cmd = ["sips", "-s", "format", "jpeg" if as_jpg else "png"]
    if as_jpg:
        cmd += ["-s", "formatOptions", str(quality)]
    if max(w, h) > max_side:
        cmd += ["-Z", str(max_side)]
    subprocess.run(cmd + [str(src), "--out", str(dst)], capture_output=True, check=True)
    new_w, new_h, _ = sips_info(dst)
    return dst.read_bytes(), "image/jpeg" if as_jpg else "image/png", (w, h), (new_w, new_h)


def scale_to(gltf, height):
    """Escala los nodos raíz para que el modelo mida `height` m de alto (malla sin tocar)."""
    ys = [(a["min"][1], a["max"][1]) for a in gltf["accessors"] if a.get("type") == "VEC3" and "min" in a][:1]
    if not ys:
        return
    current = ys[0][1] - ys[0][0]
    factor = height / current
    for root in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        node = gltf["nodes"][root]
        node["scale"] = [v * factor for v in node.get("scale", [1, 1, 1])]
    print(f"  altura: {current:.3f} m -> {height:.2f} m (×{factor:.1f})")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("origen", type=Path)
    ap.add_argument("destino", type=Path, nargs="?")
    ap.add_argument("--max", type=int, default=1024, help="lado máximo de las texturas (por defecto 1024)")
    ap.add_argument("--altura", type=float, help="altura final en metros (escala todo el modelo)")
    ap.add_argument("--calidad", type=int, default=88, help="calidad JPG 1-100 (por defecto 88)")
    args = ap.parse_args()
    if not shutil.which("sips"):
        sys.exit("Hace falta `sips` (macOS).")
    dest = args.destino or ROOT / "assets/modelos" / args.origen.name.lower().replace(" ", "_")
    dest.parent.mkdir(parents=True, exist_ok=True)

    gltf, binary = read_glb(args.origen)
    views = gltf["bufferViews"]
    images = {im["bufferView"]: i for i, im in enumerate(gltf.get("images", [])) if "bufferView" in im}
    # Reconstruye el buffer vista a vista, cambiando solo las de imágenes.
    new_bin = bytearray()
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        for vi, view in enumerate(views):
            off = view.get("byteOffset", 0)
            chunk = binary[off:off + view["byteLength"]]
            if vi in images:
                image = gltf["images"][images[vi]]
                chunk, image["mimeType"], old, new = shrink(chunk, image.get("mimeType", "image/png"),
                                                             args.max, args.calidad, tmp)
                print(f"  textura {images[vi]}: {old[0]}×{old[1]} -> {new[0]}×{new[1]} ({image['mimeType']}, {len(chunk) // 1024} KB)")
            new_bin += b"\0" * (-len(new_bin) % 4)
            view["byteOffset"] = len(new_bin)
            view["byteLength"] = len(chunk)
            new_bin += chunk
    gltf["buffers"][0]["byteLength"] = len(new_bin)
    if args.altura:
        scale_to(gltf, args.altura)
    write_glb(dest, gltf, bytes(new_bin))
    before, after = args.origen.stat().st_size, dest.stat().st_size
    print(f"{dest}: {before / 1e6:.1f} MB -> {after / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
