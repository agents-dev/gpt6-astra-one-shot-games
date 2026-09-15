#!/bin/sh
# Portable validation startup: install, build (when needed), serve foreground.
# Serves this project root on $PORT (default 3000) so both games are reachable:
#   /mosswing/mosswing.html  /melon-lab/src/public/  /melon-lab/<standalone>.html
set -eu

# Always run from the project root (the script directory).
cd "$(dirname "$0")"

: "${PORT:=3000}"

# Minimal per-command timing + logging (portable sh, no bashisms).
run() {
  echo "+ $*"
  start=$(date +%s)
  "$@"
  rc=$?
  end=$(date +%s)
  echo "done in $((end - start))s (rc=$rc): $*"
  return $rc
}

echo "== startup: root=$(pwd) PORT=$PORT =="

# 1) Install required dependencies (no-ops today, keeps validation portable).
if command -v npm >/dev/null 2>&1; then
  if [ -f melon-lab/src/package.json ]; then
    run npm --prefix melon-lab/src install --no-audit --no-fund || echo "warn: melon-lab npm install failed, continuing"
  else
    echo "skip: melon-lab/src/package.json not found"
  fi
else
  echo "skip: npm not found, no dependencies to install"
fi

# 2) Build when needed (cheap + idempotent; never fails startup if tools are missing).
if command -v python3 >/dev/null 2>&1; then
  if [ -f mosswing/src/build.py ]; then
    run python3 mosswing/src/build.py || echo "warn: mosswing build failed, serving existing mosswing.html"
  fi
else
  echo "skip: python3 not found, serving existing mosswing/mosswing.html"
fi

if command -v npm >/dev/null 2>&1; then
  if [ -f melon-lab/src/package.json ]; then
    run npm --prefix melon-lab/src run build --if-present || echo "warn: melon-lab build failed, serving existing melon-lab/src/public"
  fi
fi

# 3) Serve the project root in the foreground (exec: keeps signals + container PID 1 happy).
echo "== serving $(pwd) on 0.0.0.0:$PORT =="
if command -v python3 >/dev/null 2>&1; then
  run exec python3 -m http.server "$PORT" --bind 0.0.0.0
elif command -v node >/dev/null 2>&1; then
  echo "python3 missing, falling back to node static server"
  run exec node -e 'const http=require("node:http"),fs=require("node:fs"),path=require("node:path");const root=process.cwd();const mime={".html":"text/html; charset=utf-8",".js":"text/javascript; charset=utf-8",".css":"text/css; charset=utf-8",".png":"image/png",".json":"application/json"};http.createServer((req,res)=>{try{const u=new URL(req.url,"http://localhost");let p=path.normalize(decodeURIComponent(u.pathname)).replace(/^(\.\.[\/\\])+/, "");let f=path.join(root,p==="/"?"":p);if(fs.existsSync(f)&&fs.statSync(f).isDirectory())f=path.join(f,"index.html");const d=fs.readFileSync(f);res.writeHead(200,{"Content-Type":mime[path.extname(f)]||"application/octet-stream","Cache-Control":"no-cache"});res.end(d);}catch(e){res.writeHead(404);res.end("Not found");}}).listen(Number(process.env.PORT||3000),"0.0.0.0",()=>console.log("serving "+root+" on :"+(process.env.PORT||3000)));'
else
  echo "error: need python3 or node to serve" >&2
  exit 1
fi
