#!/usr/bin/env bash
set -eo pipefail

ROOT="$(cd "$(dirname "$0")/.."; pwd)"
WORK="$ROOT/.swiftgodot-build"
OUT="$ROOT/ios/Vendor"

SWIFTGODOT_REPO="https://github.com/migueldeicaza/SwiftGodot.git"
SWIFTGODOTKIT_REPO="https://github.com/migueldeicaza/SwiftGodotKit.git"

# Tags que quieres usar (puedes override con variables de entorno)
SWIFTGODOT_TAG="${SWIFTGODOT_TAG:-0.60.1}"
SWIFTGODOTKIT_TAG="${SWIFTGODOTKIT_TAG:-0.60.2}"

echo "🧹 Limpiando caches SPM (opcional)…"
rm -rf ~/Library/Caches/org.swift.swiftpm/* || true
rm -rf ~/Library/Developer/Xcode/DerivedData/*/SourcePackages || true

rm -rf "$WORK" && mkdir -p "$WORK" "$OUT"
echo "➡️  Clonando repos…"
git clone --depth 1 "$SWIFTGODOT_REPO" "$WORK/SwiftGodot"
git clone --depth 1 "$SWIFTGODOTKIT_REPO" "$WORK/SwiftGodotKit"

# Pin tags
( cd "$WORK/SwiftGodot" && git fetch --tags && git checkout "tags/$SWIFTGODOT_TAG" -b "build-$SWIFTGODOT_TAG" || true )
( cd "$WORK/SwiftGodotKit" && git fetch --tags && git checkout "tags/$SWIFTGODOTKIT_TAG" -b "build-$SWIFTGODOTKIT_TAG" || true )

echo "SwiftGodot tag:     $(cd "$WORK/SwiftGodot" && git describe --tags --always)"
echo "SwiftGodotKit tag:  $(cd "$WORK/SwiftGodotKit" && git describe --tags --always)"

# Evita arrastre de versiones viejas
rm -f "$WORK/SwiftGodot/Package.resolved" "$WORK/SwiftGodotKit/Package.resolved" || true

# === Detecta URL del artefacto desde Package.swift o usa fallback ===
PKG="$WORK/SwiftGodotKit/Package.swift"
DETECTED_URL="$(grep -Eo 'https?://[^"]+ios_libgodot\.xcframework\.zip' "$PKG" || true)"
ARTIFACT_URL="${ARTIFACT_URL:-${DETECTED_URL:-https://github.com/migueldeicaza/SwiftGodotKit/releases/download/${SWIFTGODOTKIT_TAG}/ios_libgodot.xcframework.zip}}"

echo "📦 Artefacto: $ARTIFACT_URL"
DL="$WORK/SwiftGodotKit/ios_libgodot.xcframework.zip"

# === Descarga con progreso y stats ===
if [ ! -f "$DL" ]; then
  echo "⬇️  Descargando (con progreso en vivo)…"
  curl -L --progress-bar --fail --retry 3 --retry-max-time 300 --continue-at - \
    "$ARTIFACT_URL" -o "$DL"
  # Stats finales
  curl -L -s -o /dev/null "$ARTIFACT_URL" \
    -w "✅ Descargado: %{size_download} bytes en %{time_total}s (%{speed_download} B/s)\n" || true
else
  echo "ℹ️  Ya existe: $DL"
fi

# === Descomprime a libgodot.xcframework ===
echo "📦 Descomprimiendo xcframework…"
rm -rf "$WORK/SwiftGodotKit/libgodot.xcframework"
unzip -q "$DL" -d "$WORK/SwiftGodotKit"
[ -d "$WORK/SwiftGodotKit/libgodot.xcframework" ] || { echo "❌ No se encontró libgodot.xcframework"; exit 1; }

# === Parchea Package.swift para usar el artefacto local ===
if grep -q "binaryTarget" "$PKG"; then
  echo "🧩 Parcheando Package.swift → binaryTarget(path: ./libgodot.xcframework)…"
  # reemplazo amplio para cualquier forma url/checksum → path
  sed -i.bak 's#binaryTarget([^)]*)#binaryTarget(name: "libgodot", path: "./libgodot.xcframework")#' "$PKG" || true
  if grep -q "url:" "$PKG"; then
    sed -i.bak 's#url: *"[^"]*", *checksum: *"[^"]*"#path: "./libgodot.xcframework"#' "$PKG" || true
  fi
fi

# Fuerza que SwiftGodot pida exactamente 0.60.2 de SwiftGodotKit (si usa "from:")
SGPKG="$WORK/SwiftGodot/Package.swift"
if grep -q "SwiftGodotKit" "$SGPKG"; then
  sed -i.bak 's#\(SwiftGodotKit[",:].*from:\s*\)"[^"]*"#\1"0.60.2"#' "$SGPKG" || true
  sed -i ''  's#\(SwiftGodotKit[",:].*from:\s*\)"[^"]*"#\1"0.60.2"#' "$SGPKG" 2>/dev/null || true
fi

resolve_with_retries () {
  local SCHEME="$1"
  local PROJ_DIR="$2"
  for attempt in 1 2 3; do
    echo "🔁 Resolviendo paquetes para ${SCHEME} (intento ${attempt}/3)…"
    if xcodebuild -resolvePackageDependencies -scheme "$SCHEME" -destination "generic/platform=iOS" -quiet; then
      return 0
    fi
    sleep 2
  done
  echo "❌ Falló la resolución de paquetes para ${SCHEME}"; return 1
}

build_framework () {
  local NAME="$1"
  local PROJ_DIR="$2"
  pushd "$PROJ_DIR" >/dev/null

  resolve_with_retries "$NAME" "$PROJ_DIR"

  echo "🏗️  Compilando $NAME (iOS DEVICE)…"
  xcodebuild -scheme "$NAME" -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$WORK/$NAME-iOS.xcarchive" \
    SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    archive

  echo "🏗️  Compilando $NAME (iOS SIM)…"
  xcodebuild -scheme "$NAME" -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$WORK/$NAME-Sim.xcarchive" \
    SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    archive

  echo "🧱 Creando $NAME.xcframework…"
  xcodebuild -create-xcframework \
    -framework "$WORK/$NAME-iOS.xcarchive/Products/Library/Frameworks/$NAME.framework" \
    -framework "$WORK/$NAME-Sim.xcarchive/Products/Library/Frameworks/$NAME.framework" \
    -output "$OUT/$NAME.xcframework"

  popd >/dev/null
}

build_framework "SwiftGodot" "$WORK/SwiftGodot"
build_framework "SwiftGodotKit" "$WORK/SwiftGodotKit"

echo "✅ Listo en: $OUT"
ls -1 "$OUT"
