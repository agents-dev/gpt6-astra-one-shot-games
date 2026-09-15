#!/bin/sh
# Portable startup: cd to own dir, install, build, serve foreground on ${PORT:-3000}.
set -eu
cd "$(dirname "$0")"
PORT="${PORT:-3000}"
echo "[startup] dir=$(pwd) PORT=$PORT"

echo "[startup] (1/3) install dependencies"
S1=$(date +%s)
if command -v npm >/dev/null 2>&1 && [ -f melon-lab/src/package.json ]; then
  time npm --prefix melon-lab/src install --no-audit --no-fund || echo "[startup] npm install failed, continuing"
else
  echo "[startup] npm or melon-lab/src/package.json not found, nothing to install"
fi
E1=$(date +%s)
echo "[timing] install took $((E1 - S1))s"

echo "[startup] (2/3) build"
S2=$(date +%s)
if command -v python3 >/dev/null 2>&1 && [ -f mosswing/src/build.py ]; then
  time python3 mosswing/src/build.py
else
  echo "[startup] python3/build.py missing, skipping mosswing build"
fi
if [ -f mosswing/mosswing.html ]; then
  time cp mosswing/mosswing.html index.html
  echo "[startup] synced index.html from mosswing/mosswing.html"
fi
if command -v node >/dev/null 2>&1 && [ -f melon-lab/src/build.mjs ]; then
  time node melon-lab/src/build.mjs || echo "[startup] melon-lab build failed, continuing"
fi
E2=$(date +%s)
echo "[timing] build took $((E2 - S2))s"

echo "[startup] (3/3) serve foreground on port $PORT"
S3=$(date +%s)
echo "[timing] serve starting after $((S3 - S1))s total setup"
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "$PORT" --bind 0.0.0.0
elif command -v python >/dev/null 2>&1; then
  exec python -m http.server "$PORT"
elif command -v npx >/dev/null 2>&1; then
  exec npx -y serve -l "$PORT" .
else
  echo "[startup] ERROR: no python3/python/npx found to serve" >&2
  exit 1
fi
