#!/usr/bin/env bash
set -eo pipefail

# =========================================================
# Compila Godot para iOS (device+sim), crea ios_libgodot.xcframework,
# parchea SwiftGodotKit para usar artefacto local (sin descargas),
# y construye SwiftGodot.xcframework + SwiftGodotKit.xcframework.
# =========================================================

# --- Config editable por env ----------------------------------------------
GODOT_REPO="${GODOT_REPO:-https://github.com/godotengine/godot.git}"
GODOT_TAG="${GODOT_TAG:-4.4-stable}"          # etiqueta de Godot que quieres
SWIFTGODOT_REPO="${SWIFTGODOT_REPO:-https://github.com/migueldeicaza/SwiftGodot.git}"
SWIFTGODOT_TAG="${SWIFTGODOT_TAG:-0.60.1}"
SWIFTGODOTKIT_REPO="${SWIFTGODOTKIT_REPO:-https://github.com/migueldeicaza/SwiftGodotKit.git}"
SWIFTGODOTKIT_TAG="${SWIFTGODOTKIT_TAG:-0.60.2}"

# Dónde dejar resultados
ROOT="$(cd "$(dirname "$0")/.."; pwd)"
WORK="${WORK:-$ROOT/.local-build}"
OUT="${OUT:-$ROOT/ios/Vendor}"

# Flags Godot build (ajusta si lo necesitas)
# target=template_release es lo que normalmente se usa para runtime
GODOT_TARGET="${GODOT_TARGET:-template_release}"
USE_LTO="${USE_LTO:-yes}"                  # yes/no
DEBUG_SYMBOLS="${DEBUG_SYMBOLS:-no}"       # no/yes para achicar
IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-13.0}"

# --------------------------------------------------------------------------

log(){ echo "[$(date +'%F %T')] $*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "Falta la herramienta '$1' en PATH"
}

log "Chequeando herramientas…"
require git
require python3
require xcodebuild
if ! command -v scons >/dev/null 2>&1; then
  log "No encuentro 'scons'. Instalalo con:  brew install scons   (o pip3 install scons)"
  die "scons es requerido"
fi

# Xcode SDK check (por si acaso)
SDKVER=$(xcrun --sdk iphoneos --show-sdk-version || true)
[[ -n "$SDKVER" ]] || die "No se detecta iOS SDK. Abre Xcode al menos una vez."

# Preparar directorios
rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"

# =========================
# 1) Clonar repos
# =========================
log "Clonando Godot ($GODOT_TAG)…"
git clone --depth 1 --branch "$GODOT_TAG" "$GODOT_REPO" "$WORK/godot"

log "Clonando SwiftGodot ($SWIFTGODOT_TAG)…"
git clone --depth 1 "$SWIFTGODOT_REPO" "$WORK/SwiftGodot"
( cd "$WORK/SwiftGodot" && git fetch --tags && git checkout "tags/$SWIFTGODOT_TAG" -b "build-$SWIFTGODOT_TAG" ) || true

log "Clonando SwiftGodotKit ($SWIFTGODOTKIT_TAG)…"
git clone --depth 1 "$SWIFTGODOTKIT_REPO" "$WORK/SwiftGodotKit"
( cd "$WORK/SwiftGodotKit" && git fetch --tags && git checkout "tags/$SWIFTGODOTKIT_TAG" -b "build-$SWIFTGODOTKIT_TAG" ) || true

# Evitar arrastres de caches SPM
rm -f "$WORK/SwiftGodot/Package.resolved" "$WORK/SwiftGodotKit/Package.resolved" || true

# =========================
# 2) Compilar Godot iOS (device + simulator)
# =========================
log "Compilando Godot (iOS DEVICE arm64)…"
pushd "$WORK/godot" >/dev/null
python3 - <<'PY'
import os
# Crear un 'custom.py' para forzar IPHONEOS_DEPLOYMENT_TARGET si hace falta
cfg = f"""
IPHONEOS_DEPLOYMENT_TARGET = "{os.environ.get('IPHONEOS_DEPLOYMENT_TARGET','13.0')}"
"""
open('custom.py','w').write(cfg)
print("Escribí custom.py con IPHONEOS_DEPLOYMENT_TARGET")
PY

# DEVICE
scons platform=ios target=$GODOT_TARGET arch=arm64 ios_simulator=no \
  use_lto=$USE_LTO debug_symbols=$DEBUG_SYMBOLS tools=no verbose=no

# SIMULATOR (arm64) — si quieres también x86_64, añade arch=x86_64 en otra pasada
log "Compilando Godot (iOS SIMULATOR arm64)…"
scons platform=ios target=$GODOT_TARGET arch=arm64 ios_simulator=yes \
  use_lto=$USE_LTO debug_symbols=$DEBUG_SYMBOLS tools=no verbose=no

popd >/dev/null

# Detectar nombres de .a (Godot cambia nombres según versión/flags)
find_lib() {
  local dir="$1"
  local pattern="$2"
  local f
  f=$(ls "$dir"/$pattern 2>/dev/null | head -n1 || true)
  [[ -f "$f" ]] || return 1
  echo "$f"
}
GODOT_BIN="$WORK/godot/bin"

LIB_DEV="$(find_lib "$GODOT_BIN" "libgodot.*ios.*release*.arm64*.a" || true)"
[[ -n "$LIB_DEV" ]] || LIB_DEV="$(find_lib "$GODOT_BIN" "libgodot.*ios.*template*.arm64*.a" || true)"
[[ -n "$LIB_DEV" ]] || die "No encontré librería DEVICE en $GODOT_BIN"

LIB_SIM="$(find_lib "$GODOT_BIN" "libgodot.*ios.*release*.simulator.arm64*.a" || true)"
[[ -n "$LIB_SIM" ]] || LIB_SIM="$(find_lib "$GODOT_BIN" "libgodot.*ios.*template*.simulator.arm64*.a" || true)"
[[ -n "$LIB_SIM" ]] || die "No encontré librería SIMULATOR en $GODOT_BIN"

log "DEVICE lib:    $LIB_DEV"
log "SIMULATOR lib: $LIB_SIM"

# =========================
# 3) Crear ios_libgodot.xcframework local
# =========================
log "Creando ios_libgodot.xcframework…"
TMPXC="$WORK/libgodot_xc"
rm -rf "$TMPXC"
mkdir -p "$TMPXC"

# Si tu integración necesita headers, puedes apuntar a un dir de headers.
# SwiftGodotKit usa el binario como artifact; normalmente NO requiere headers.
xcodebuild -create-xcframework \
  -library "$LIB_DEV" -headers "$WORK/godot" \
  -library "$LIB_SIM" -headers "$WORK/godot" \
  -output "$WORK/SwiftGodotKit/libgodot.xcframework"

[[ -d "$WORK/SwiftGodotKit/libgodot.xcframework" ]] || die "Fallo creando libgodot.xcframework"

# =========================
# 4) Parchear SwiftGodotKit para usar el artefacto local
# =========================
PKG="$WORK/SwiftGodotKit/Package.swift"
if grep -q "binaryTarget" "$PKG"; then
  log "Parcheando SwiftGodotKit/Package.swift → usar path local ./libgodot.xcframework…"
  # Reemplazo amplio a path local
  sed -i.bak 's#binaryTarget([^)]*)#binaryTarget(name: "libgodot", path: "./libgodot.xcframework")#' "$PKG" || true
  # Si quedara url/checksum, reemplaza también
  if grep -q "url:" "$PKG"; then
    sed -i.bak 's#url: *"[^"]*", *checksum: *"[^"]*"#path: "./libgodot.xcframework"#' "$PKG" || true
  fi
  # BSD sed fallback (macOS)
  if [[ -f "$PKG.bak" ]]; then
    sed -i '' 's#binaryTarget([^)]*)#binaryTarget(name: "libgodot", path: "./libgodot.xcframework")#' "$PKG" 2>/dev/null || true
    sed -i '' 's#url: *"[^"]*", *checksum: *"[^"]*"#path: "./libgodot.xcframework"#' "$PKG" 2>/dev/null || true
  fi
fi

# Forzar que SwiftGodot pida la versión correcta de SwiftGodotKit (exacta), por si usaba from:
SGPKG="$WORK/SwiftGodot/Package.swift"
if grep -q "SwiftGodotKit" "$SGPKG"; then
  sed -i.bak 's#\(SwiftGodotKit[",:].*from:\s*\)"[^"]*"#\1"'"$SWIFTGODOTKIT_TAG"'"#' "$SGPKG" || true
  sed -i ''  's#\(SwiftGodotKit[",:].*from:\s*\)"[^"]*"#\1"'"$SWIFTGODOTKIT_TAG"'"#' "$SGPKG" 2>/dev/null || true
fi

# =========================
# 5) Construir SwiftGodot.xcframework y SwiftGodotKit.xcframework
# =========================

resolve_with_retries () {
  local SCHEME="$1"
  local PROJ_DIR="$2"
  for attempt in 1 2 3; do
    log "Resolviendo paquetes para ${SCHEME} (intento ${attempt}/3)…"
    if xcodebuild -resolvePackageDependencies -scheme "$SCHEME" -destination "generic/platform=iOS" -quiet; then
      return 0
    fi
    sleep 2
  done
  die "Falló la resolución de paquetes para ${SCHEME}"
}

build_swiftpkg_xcframework () {
  local NAME="$1"
  local PROJ_DIR="$2"
  pushd "$PROJ_DIR" >/dev/null

  resolve_with_retries "$NAME" "$PROJ_DIR"

  log "Archivando $NAME (iOS DEVICE)…"
  xcodebuild -scheme "$NAME" -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$WORK/$NAME-iOS.xcarchive" \
    SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    archive

  log "Archivando $NAME (iOS SIM)…"
  xcodebuild -scheme "$NAME" -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$WORK/$NAME-Sim.xcarchive" \
    SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    archive

  log "Creando $NAME.xcframework…"
  xcodebuild -create-xcframework \
    -framework "$WORK/$NAME-iOS.xcarchive/Products/Library/Frameworks/$NAME.framework" \
    -framework "$WORK/$NAME-Sim.xcarchive/Products/Library/Frameworks/$NAME.framework" \
    -output "$OUT/$NAME.xcframework"

  popd >/dev/null
}

log "Construyendo SwiftGodot.xcframework…"
build_swiftpkg_xcframework "SwiftGodot" "$WORK/SwiftGodot"

log "Construyendo SwiftGodotKit.xcframework…"
build_swiftpkg_xcframework "SwiftGodotKit" "$WORK/SwiftGodotKit"

log "✅ Listo. Artefactos en: $OUT"
ls -1 "$OUT" || true

echo "----------------------------------------------------------------"
echo "Si quieres que tu Podspec use estos frameworks vendorizados, apunta a:"
echo "  $OUT/SwiftGodot.xcframework"
echo "  $OUT/SwiftGodotKit.xcframework"
echo "Y recuerda que tu lib RN copiará el .pck al bundle en iOS."
echo "----------------------------------------------------------------"
