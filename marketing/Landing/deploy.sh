#!/usr/bin/env bash
# Deploy de la landing de Home Finance a Firebase Hosting, en la ruta /get/
#
# Por qué este enfoque (stage-into-dist, SIN npm run build):
#   - `npm run build` corre scripts/copy-public.mjs, que copia una LISTA FIJA de
#     archivos y NO incluye account-deletion.html (página legal requerida por
#     Google Play). Un rebuild podría dejarla afuera del deploy. Por eso solo
#     agregamos la landing a dist/ y deployamos, sin reconstruir la PWA.
#   - La landing usa paths RELATIVOS (assets/...), por eso funciona dentro de /get/.
#   - firebase.json tiene un rewrite SPA (** -> /index.html), pero los archivos
#     físicos tienen prioridad, así que /get/index.html y /get/assets/* se sirven OK.
#
# Requisito: estar logueado en Firebase.
#   Si falla con "Failed to authenticate", corré:  firebase login --reauthenticate
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"   # raíz del repo
SRC="$ROOT/marketing/Landing"
DST="$ROOT/dist/get"
FB="$(command -v firebase || echo /usr/local/bin/firebase)"

echo "▸ Staging landing → dist/get/"
rm -rf "$DST"
mkdir -p "$DST"
cp "$SRC/index.html" "$DST/"
cp -R "$SRC/assets" "$DST/"
# nunca deployar README / scripts / temporales
rm -f "$DST/README.md" "$DST/.gitignore" "$DST"/_check*.png "$DST/deploy.sh" 2>/dev/null || true

echo "▸ Archivos a publicar:"
find "$DST" -type f | sed "s|$ROOT/||" | sort

echo "▸ Verificando que las páginas legales sigan en dist/ (no las pisamos)…"
for f in privacy.html terms.html account-deletion.html; do
  [ -f "$ROOT/dist/$f" ] && echo "  ✓ dist/$f" || { echo "  ✗ FALTA dist/$f — abortando"; exit 1; }
done

echo "▸ Deploy a Firebase Hosting (solo hosting)…"
( cd "$ROOT" && "$FB" deploy --only hosting )

echo "✅ Listo. Landing en: https://metacasa-app-cf592.web.app/get/"
