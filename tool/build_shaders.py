#!/usr/bin/env python3
"""Assemble les shaders Droplet Matter.

Flutter compile chaque fichier .frag séparément et ne garantit pas les
#include relatifs. Les sources de shaders/src incluent donc les fichiers de
shaders/lib, et ce script produit des fichiers autonomes :

  shaders/<nom>.frag          pour Flutter (déclarés dans pubspec.yaml)
  tool/bench/<nom>.webgl.frag pour le banc d'essai WebGL local (option --webgl)

Usage : python3 tool/build_shaders.py [--webgl] [--check]
  --check  échoue si un fichier généré n'est pas à jour (utilisé en CI).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "shaders" / "src"
OUT = ROOT / "shaders"
BENCH = ROOT / "tool" / "bench"
INCLUDE = re.compile(r'^\s*#include\s+"([^"]+)"\s*$')

FLUTTER_HEADER = (
    "// FICHIER GÉNÉRÉ par tool/build_shaders.py depuis shaders/src : ne pas modifier.\n"
    "#version 460 core\n"
    "#include <flutter/runtime_effect.glsl>\n"
    "precision highp float;\n"
)
WEBGL_HEADER = (
    "#version 300 es\n"
    "precision highp float;\n"
    "#define FlutterFragCoord() vec2(gl_FragCoord.x, uSize.y - gl_FragCoord.y)\n"
)


def expand(path: pathlib.Path, seen: set) -> str:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = INCLUDE.match(line)
        if m:
            target = (path.parent / m.group(1)).resolve()
            if target in seen:
                continue
            seen.add(target)
            out.append(f"// ---- {target.relative_to(ROOT)} ----")
            out.append(expand(target, seen))
        else:
            out.append(line)
    return "\n".join(out)


def main() -> int:
    webgl = "--webgl" in sys.argv
    check = "--check" in sys.argv
    stale = []
    for src in sorted(SRC.glob("*.frag")):
        body = expand(src, set())
        flutter = FLUTTER_HEADER + body + "\n"
        dest = OUT / src.name
        if check:
            if not dest.exists() or dest.read_text(encoding="utf-8") != flutter:
                stale.append(dest.name)
        else:
            dest.write_text(flutter, encoding="utf-8")
        if webgl:
            BENCH.mkdir(parents=True, exist_ok=True)
            (BENCH / src.name.replace(".frag", ".webgl.frag")).write_text(WEBGL_HEADER + body + "\n", encoding="utf-8")
    if stale:
        print("Shaders générés pas à jour : " + ", ".join(stale) + ". Lancez python3 tool/build_shaders.py")
        return 1
    print("Shaders assemblés.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
