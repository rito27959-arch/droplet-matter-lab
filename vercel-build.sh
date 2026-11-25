#!/usr/bin/env bash
# Construction Vercel : installe Flutter (canal stable), puis compile
# l'application d'essai pour le web. Sortie : sample/build/web (voir vercel.json).
set -euo pipefail

if [ ! -x .flutter/bin/flutter ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git .flutter
fi
export PATH="$PWD/.flutter/bin:$PATH"
flutter config --no-analytics >/dev/null
flutter --version

# Les shaders générés doivent correspondre à leurs sources.
if command -v python3 >/dev/null; then python3 tool/build_shaders.py --check; fi

cd sample
flutter pub get
flutter build web --release
