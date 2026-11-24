#!/usr/bin/env python3
"""Copia organizada de las imágenes del juego fuera del proyecto.

Repasa las carpetas de imágenes del proyecto y la carpeta organizada
(por defecto ~/Documents/assets-game) y clasifica todo automáticamente:

    assets-game/
      Personajes/<Nombre>/            ren.png, kenji_enfado.png...
      Enemigos/<Tipo>/                oni.png, turbina.png... (tipo = naturaleza)
      Ubicaciones/<Nombre>/<Momento>/ instituto.png (Cualquier momento),
                                      instituto_noche.png (Noche)...
      Ubicaciones/<Nombre>/Objetos/   objetos examinables (cama.png...)
      Ubicaciones/<Nombre>/Personajes/ poses de los personajes en ese lugar (kenji.png...)
      Ubicaciones/<Nombre>/Combate/   fondo de combate de una mazmorra
      Sin clasificar/                 lo que no sabe dónde va
      Versiones anteriores/           lo que se ha sustituido por algo más nuevo

Qué hace:
  1. Proyecto -> carpeta: copia cada imagen a su sitio (si falta o ha cambiado
     en el proyecto).
  2. Ordena la carpeta: lo que esté mal colocado (p. ej. una imagen soltada en
     la raíz) va a su sitio según su nombre; lo que no reconoce, a «Sin
     clasificar».
  3. Avisa de lo que está en la carpeta y no en el proyecto (o es más nuevo).
     Con --importar lo copia al proyecto con el nombre que espera el juego.

Nunca borra nada: lo sustituido va a «Versiones anteriores». Personajes,
ubicaciones, naturalezas y franjas se leen del propio código del juego, así
que un personaje o una ubicación nuevos se clasifican solos.

Convenciones de nombre (las que usa el juego):
  personajes  <id>.png y <id>_<gesto>.png        (assets/characters/)
  enemigos    nombre de su `portrait`            (assets/enemies/)
  fondos      <id>.png y <id>_<franja>.png       (assets/backgrounds/)
              franjas: manana, dia, tarde, noche
  objetos     los de `props` de cada ubicación   (assets/props/)
  poses       <personaje>.png de cada lugar      (assets/escenas/<id del lugar>/)

Uso:
  tools/assets/organizar.sh               # organiza y avisa
  tools/assets/organizar.sh --prueba      # solo dice lo que haría
  tools/assets/organizar.sh --importar    # además, lleva lo nuevo al proyecto
  tools/assets/organizar.sh --destino /otra/carpeta
"""

import argparse
import filecmp
import os
import re
import shutil
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp"}
ANY_TIME = "Cualquier momento"
UNSORTED = "Sin clasificar"
OLD = "Versiones anteriores"

PROJECT_DIRS = {
    "characters": ROOT / "assets/characters",
    "enemies": ROOT / "assets/enemies",
    "backgrounds": ROOT / "assets/backgrounds",
    "props": ROOT / "assets/props",
    "escenas": ROOT / "assets/escenas",
}
POSES = "Personajes"


# --- Datos del juego (leídos del código) ----------------------------------------------

def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def blocks(text, const):
    """Entradas `"id": { ... }` de primer nivel de `const NAME := { ... }`."""
    start = text.index("const %s := {" % const)
    i = text.index("{", start) + 1
    depth, out, key, body_start = 1, {}, None, None
    while depth > 0:
        c = text[i]
        if c == "{":
            if depth == 1:
                m = re.search(r'"(\w+)":\s*$', text[max(0, i - 80):i])
                key, body_start = (m.group(1) if m else None), i
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 1 and key:
                out[key] = text[body_start:i + 1]
                key = None
        i += 1
    return out


def field(body, name):
    m = re.search(r'"%s":\s*"([^"]*)"' % name, body)
    return m.group(1) if m else ""


def load_game_data():
    chars = {}
    char_text = read("src/data/character_db.gd")
    for cid, body in blocks(char_text, "ALL").items():
        portrait = field(body, "portrait")
        nature = field(body, "nature")
        profile = ROOT / "src/data/characters" / (cid + ".json")
        if not nature and profile.exists():
            m = re.search(r'"nature":\s*"([^"]+)"', profile.read_text(encoding="utf-8"))
            nature = m.group(1) if m else ""
        chars[cid] = {
            "name": field(body, "name"),
            "enemy": '"enemy": true' in body,
            "nature": nature,
            "portrait": Path(portrait).stem if portrait else "",
        }
    natures = dict(re.findall(r'"(\w+)":\s*"([^"]+)"',
                              re.search(r"const NATURE_NAMES := \{(.*?)\}", read("src/data/skill_db.gd"), re.S).group(1)))
    slots = re.findall(r'\{"id": "(\w+)", "name": "([^"]+)"',
                       re.search(r"const TIME_SLOTS := \[(.*?)\]", read("src/autoload/game_state.gd"), re.S).group(1))
    locs = {}
    for lid, body in blocks(read("src/data/location_db.gd"), "ALL").items():
        battle = field(body, "battle_background")
        locs[lid] = {
            "name": field(body, "name"),
            "props": [Path(p).stem for p in re.findall(r'"texture":\s*"([^"]+)"', body)],
            "battle": Path(battle).stem if battle else "",
        }
    return chars, natures, slots, locs


# --- Clasificación ------------------------------------------------------------------------

class Classifier:
    def __init__(self, chars, natures, slots, locs):
        self.chars, self.natures, self.locs = chars, natures, locs
        self.slots = dict(slots)                       # id -> nombre ("noche" -> "Noche")
        self.slot_ids = {v: k for k, v in self.slots.items()}

    def nature_name(self, nature):
        return self.natures.get(nature, "Sin tipo").replace("/", "-")

    def classify(self, stem):
        """(carpeta relativa, carpeta del proyecto) según el nombre, o None."""
        for lid, loc in self.locs.items():
            if stem == loc["battle"]:
                return Path("Ubicaciones", loc["name"], "Combate"), "backgrounds"
            if stem in loc["props"]:
                return Path("Ubicaciones", loc["name"], "Objetos"), "props"
        for cid, ch in self.chars.items():
            if ch["enemy"] and stem == ch["portrait"]:
                return Path("Enemigos", self.nature_name(ch["nature"])), "enemies"
        # Personajes: el id más largo que encaje (madre_kenji antes que kenji).
        for cid in sorted(self.chars, key=len, reverse=True):
            ch = self.chars[cid]
            if not ch["enemy"] and (stem == cid or stem.startswith(cid + "_")):
                return Path("Personajes", ch["name"]), "characters"
        for lid in sorted(self.locs, key=len, reverse=True):
            loc = self.locs[lid]
            if stem == lid:
                return Path("Ubicaciones", loc["name"], ANY_TIME), "backgrounds"
            if stem.startswith(lid + "_") and stem[len(lid) + 1:] in self.slots:
                return Path("Ubicaciones", loc["name"], self.slots[stem[len(lid) + 1:]]), "backgrounds"
        return None

    def loc_by_name(self, name):
        for lid, loc in self.locs.items():
            if loc["name"] == name:
                return lid
        return None

    def pose_dir(self, rel_dir):
        """id del lugar si `rel_dir` es Ubicaciones/<Nombre>/Personajes."""
        parts = rel_dir.parts
        if len(parts) == 3 and parts[0] == "Ubicaciones" and parts[2] == POSES:
            return self.loc_by_name(parts[1])
        return None

    def name_from_folder(self, rel_dir):
        """Nombre que esperaría el juego para una imagen con nombre libre metida en
        una carpeta de fondo por momento (Ubicaciones/<Nombre>/<Momento>)."""
        parts = rel_dir.parts
        if len(parts) == 3 and parts[0] == "Ubicaciones":
            for lid, loc in self.locs.items():
                if loc["name"] == parts[1]:
                    if parts[2] == ANY_TIME:
                        return lid, "backgrounds"
                    if parts[2] in self.slot_ids:
                        return lid + "_" + self.slot_ids[parts[2]], "backgrounds"
        return None

    def skeleton(self):
        dirs = [Path(UNSORTED)]
        for ch in self.chars.values():
            if not ch["enemy"] and ch["portrait"]:
                dirs.append(Path("Personajes", ch["name"]))
        for nature in self.natures:
            dirs.append(Path("Enemigos", self.nature_name(nature)))
        for loc in self.locs.values():
            for moment in [ANY_TIME] + list(self.slots.values()):
                dirs.append(Path("Ubicaciones", loc["name"], moment))
            dirs.append(Path("Ubicaciones", loc["name"], POSES))
            if loc["props"]:
                dirs.append(Path("Ubicaciones", loc["name"], "Objetos"))
            if loc["battle"]:
                dirs.append(Path("Ubicaciones", loc["name"], "Combate"))
        return dirs


# --- Operaciones ----------------------------------------------------------------------------

class Runner:
    def __init__(self, dest, dry):
        self.dest, self.dry = dest, dry
        self.log = []

    def say(self, kind, text):
        self.log.append((kind, text))

    def mkdir(self, path):
        if not self.dry:
            path.mkdir(parents=True, exist_ok=True)

    def copy(self, src, dst):
        if not self.dry:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)

    def retire(self, path):
        """Mueve `path` (dentro del destino) a «Versiones anteriores», con fecha."""
        rel = path.relative_to(self.dest)
        stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime(path.stat().st_mtime))
        target = self.dest / OLD / rel.parent / ("%s.%s%s" % (path.stem, stamp, path.suffix))
        if not self.dry:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), target)
        return target

    def move(self, src, dst):
        if not self.dry:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), dst)


def images(folder):
    if not folder.exists():
        return []
    return sorted(p for p in folder.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXT
                  and not p.name.startswith("."))


def same(a, b):
    return a.exists() and b.exists() and filecmp.cmp(a, b, shallow=False)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--destino", default=str(Path.home() / "Documents" / "assets-game"))
    ap.add_argument("--prueba", action="store_true", help="no cambia nada; solo dice lo que haría")
    ap.add_argument("--importar", action="store_true", help="copia al proyecto lo nuevo o más reciente de la carpeta")
    args = ap.parse_args()

    dest = Path(args.destino).expanduser()
    cls = Classifier(*load_game_data())
    run = Runner(dest, args.prueba)

    for d in cls.skeleton():
        run.mkdir(dest / d)

    # 1. Proyecto -> carpeta organizada.
    project_files = {}                                   # nombre de archivo -> ruta en el proyecto
    for kind, folder in PROJECT_DIRS.items():
        for src in images(folder):
            project_files[src.name] = src
            if kind == "escenas":
                lid = src.parent.name
                place = (Path("Ubicaciones", cls.locs[lid]["name"], POSES), kind) if lid in cls.locs else None
            else:
                place = cls.classify(src.stem)
            rel_dir = place[0] if place else Path(UNSORTED)
            dst = dest / rel_dir / src.name
            if not dst.exists():
                run.copy(src, dst)
                run.say("copiado", "%s -> %s" % (src.relative_to(ROOT), dst.relative_to(dest)))
            elif not same(src, dst):
                if src.stat().st_mtime > dst.stat().st_mtime:
                    old = run.retire(dst)
                    run.copy(src, dst)
                    run.say("actualizado", "%s (la anterior, en %s)" % (dst.relative_to(dest), old.relative_to(dest)))
                else:
                    run.say("más nuevo fuera", "%s es más reciente que la del proyecto" % dst.relative_to(dest))
            if not place:
                run.say("sin clasificar", "%s: el nombre no corresponde a nada del juego" % src.relative_to(ROOT))

    # 2. Ordenar la carpeta: cada imagen reconocible a su sitio.
    skip = {dest / OLD}
    for path in images(dest):
        if any(s in path.parents for s in skip):
            continue
        rel_dir = path.parent.relative_to(dest)
        if cls.pose_dir(rel_dir):
            continue                                     # pose de un personaje en ese lugar
        place = cls.classify(path.stem)
        if place:
            target = dest / place[0] / path.name
        elif cls.name_from_folder(rel_dir) or rel_dir.parts[:1] in [("Personajes",), ("Enemigos",), ("Ubicaciones",)]:
            continue                                     # nombre libre, pero en una carpeta con sentido
        else:
            target = dest / UNSORTED / path.name
        if target == path:
            continue
        if not target.exists():
            run.move(path, target)
            run.say("ordenado", "%s -> %s" % (path.relative_to(dest), target.relative_to(dest)))
        elif same(path, target):
            old = run.retire(path)
            run.say("duplicado", "%s era igual que %s (guardado en %s)" % (path.relative_to(dest), target.relative_to(dest), old.relative_to(dest)))
        else:
            newer, older = (path, target) if path.stat().st_mtime > target.stat().st_mtime else (target, path)
            old = run.retire(older)
            if newer is path:
                run.move(path, target)
            run.say("ordenado", "%s -> %s (la anterior, en %s)" % (path.relative_to(dest), target.relative_to(dest), old.relative_to(dest)))

    # 3. Lo que está fuera y no en el proyecto (o es más nuevo).
    for path in images(dest):
        if (dest / OLD) in path.parents or (dest / UNSORTED) in path.parents:
            continue
        rel_dir = path.parent.relative_to(dest)
        pose_loc = cls.pose_dir(rel_dir)
        place = None if pose_loc else cls.classify(path.stem)
        name, kind = (path.name, place[1]) if place else (None, None)
        if pose_loc:
            name, kind = path.name, "escenas"
        elif not place:
            guess = cls.name_from_folder(rel_dir)
            if not guess:
                continue
            others = [p for p in images(path.parent) if p != path and not cls.classify(p.stem)]
            if others:
                run.say("ambiguo", "%s: hay varias imágenes con nombre libre en %s; renómbralas como %s%s" % (
                    path.relative_to(dest), rel_dir, guess[0], path.suffix))
                continue
            name, kind = guess[0] + path.suffix.lower(), guess[1]
        target = PROJECT_DIRS[kind] / (Path(pose_loc) / name if pose_loc else name)
        if target.exists() and (same(path, target) or path.stat().st_mtime <= target.stat().st_mtime):
            continue
        what = "nuevo" if not target.exists() else "más reciente"
        if args.importar:
            run.copy(path, target)
            run.say("importado", "%s -> %s (%s)" % (path.relative_to(dest), target.relative_to(ROOT), what))
        else:
            run.say("por importar", "%s -> %s (%s; usa --importar)" % (path.relative_to(dest), target.relative_to(ROOT), what))

    # Resumen.
    order = ["copiado", "actualizado", "ordenado", "duplicado", "importado", "por importar",
             "más nuevo fuera", "ambiguo", "sin clasificar"]
    print("%s%s" % ("[PRUEBA: no se ha cambiado nada] " if args.prueba else "", dest))
    for kind in order:
        items = [t for k, t in run.log if k == kind]
        if items:
            print("\n%s (%d):" % (kind.capitalize(), len(items)))
            for t in items:
                print("  · " + t)
    if not run.log:
        print("Todo en orden: nada que hacer.")
    if args.importar and any(k == "importado" for k, _ in run.log):
        print("\nAbre Godot para que importe las imágenes nuevas.")


if __name__ == "__main__":
    sys.exit(main())
