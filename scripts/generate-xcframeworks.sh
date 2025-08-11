#!/usr/bin/env bash
set -eo pipefail

# =========================================================
# Build Godot for iOS (device only, arm64), create ios_libgodot.xcframework,
# patch SwiftGodotKit (incl. test binary target) to use local artifact (no downloads),
# and build SwiftGodot.xcframework + SwiftGodotKit.xcframework (device-only).
# Skips Godot compilation if an existing device arm64 static lib is detected.
# =========================================================

# --- Editable config via env ----------------------------------------------
GODOT_REPO="${GODOT_REPO:-https://github.com/godotengine/godot.git}"
GODOT_TAG="${GODOT_TAG:-4.4.1-stable}"
SWIFTGODOT_REPO="${SWIFTGODOT_REPO:-https://github.com/migueldeicaza/SwiftGodot.git}"
SWIFTGODOT_TAG="${SWIFTGODOT_TAG:-0.60.1}"
SWIFTGODOTKIT_REPO="${SWIFTGODOTKIT_REPO:-https://github.com/migueldeicaza/SwiftGodotKit.git}"
SWIFTGODOTKIT_TAG="${SWIFTGODOTKIT_TAG:-0.60.2}"

# Output folders
ROOT="$(cd "$(dirname "$0")/.."; pwd)"
WORK="${WORK:-$ROOT/.local-build}"
OUT="${OUT:-$ROOT/ios/Vendor}"

# Godot build flags
GODOT_TARGET="${GODOT_TARGET:-template_release}"  # or "release" depending on Godot version
USE_LTO="${USE_LTO:-yes}"                          # yes/no
DEBUG_SYMBOLS="${DEBUG_SYMBOLS:-no}"               # no/yes
IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-13.0}"

# Optional: set CLEAN=yes to force a clean rebuild
CLEAN="${CLEAN:-no}"

# --------------------------------------------------------------------------

log(){ echo "[$(date +'%F %T')] $*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required tool '$1' in PATH"
}

log "Checking required tools…"
require git
require python3
require xcodebuild
if ! command -v scons >/dev/null 2>&1; then
  log "Could not find 'scons'. Install with:  brew install scons   (or pip3 install scons)"
  die "scons is required"
fi

# Xcode SDK sanity check
SDKVER=$(xcrun --sdk iphoneos --show-sdk-version || true)
[[ -n "$SDKVER" ]] || die "iOS SDK not detected. Open Xcode at least once."

# Prepare folders (do not wipe WORK to allow reuse)
if [[ "$CLEAN" == "yes" ]]; then
  log "CLEAN=yes → removing $WORK"
  rm -rf "$WORK"
fi
mkdir -p "$WORK" "$OUT"

# =========================
# 1) Clone/update repositories
# =========================
if [[ ! -d "$WORK/godot/.git" ]]; then
  log "Cloning Godot ($GODOT_TAG)…"
  git clone --depth 1 --branch "$GODOT_TAG" "$GODOT_REPO" "$WORK/godot"
else
  log "Reusing existing Godot repo at $WORK/godot"
fi

if [[ ! -d "$WORK/SwiftGodot/.git" ]]; then
  log "Cloning SwiftGodot ($SWIFTGODOT_TAG)…"
  git clone --depth 1 "$SWIFTGODOT_REPO" "$WORK/SwiftGodot"
  ( cd "$WORK/SwiftGodot" && git fetch --tags && git checkout "tags/$SWIFTGODOT_TAG" -b "build-$SWIFTGODOT_TAG" ) || true
else
  log "Reusing existing SwiftGodot at $WORK/SwiftGodot"
fi

# Justo después de clonar SwiftGodot y antes de resolver paquetes:
SGROOT="$WORK/SwiftGodot"
SGPKG="$SGROOT/Package.swift"

# (añade después de clonar SwiftGodot, antes de resolver paquetes)
SGPKG="$WORK/SwiftGodot/Package.swift"

# (mantén el resto del script igual)

if [[ ! -d "$WORK/SwiftGodotKit/.git" ]]; then
  log "Cloning SwiftGodotKit ($SWIFTGODOTKIT_TAG)…"
  git clone --depth 1 "$SWIFTGODOTKIT_REPO" "$WORK/SwiftGodotKit"
  ( cd "$WORK/SwiftGodotKit" && git fetch --tags && git checkout "tags/$SWIFTGODOTKIT_TAG" -b "build-$SWIFTGODOTKIT_TAG" ) || true
else
  log "Reusing existing SwiftGodotKit at $WORK/SwiftGodotKit"
fi

# --- after cloning SwiftGodotKit, before resolve/build ---
KROOT="$WORK/SwiftGodotKit"
KPKG="$KROOT/Package.swift"

# 1) Reemplaza solo el binaryTarget 'ios_libgodot' para apuntar al path local
/usr/bin/perl -0777 -pe '
  s{
    binaryTarget\s*\(\s*name:\s*"ios_libgodot"[^)]*\)
  }{binaryTarget(name: "ios_libgodot", path: "./libgodot.xcframework")}sx
' -i "$KPKG"

# 2) Verificación rápida: debe existir exactamente UNA línea con ios_libgodot apuntando a path
grep -n 'binaryTarget(.*ios_libgodot' "$KPKG" || { echo "ios_libgodot binaryTarget not found"; exit 1; }

# Avoid stale SPM resolution
rm -f "$WORK/SwiftGodot/Package.resolved" "$WORK/SwiftGodotKit/Package.resolved" || true

# Helper to locate Godot static library
find_lib() {
  local dir="$1"
  local pattern="$2"
  local f
  f=$(ls "$dir"/$pattern 2>/dev/null | head -n1 || true)
  [[ -f "$f" ]] || return 1
  echo "$f"
}

GODOT_BIN="$WORK/godot/bin"

# Try to detect prebuilt device library BEFORE building
LIB_DEV="$(find_lib "$GODOT_BIN" "libgodot.*ios.*release*.arm64*.a" || true)"
[[ -n "$LIB_DEV" ]] || LIB_DEV="$(find_lib "$GODOT_BIN" "libgodot.*ios.*template*.arm64*.a" || true)"

# =========================
# 2) Build Godot iOS (DEVICE only, arm64) — skipped if already present
# =========================
if [[ -n "$LIB_DEV" && "$CLEAN" != "yes" ]]; then
  log "Found existing Godot device static lib → skipping compilation"
else
  log "Building Godot (iOS DEVICE arm64)…"
  pushd "$WORK/godot" >/dev/null
  python3 - <<'PY'
import os
cfg = f"""
IPHONEOS_DEPLOYMENT_TARGET = "{os.environ.get('IPHONEOS_DEPLOYMENT_TARGET','13.0')}"
"""
open('custom.py','w').write(cfg)
print("Wrote custom.py with IPHONEOS_DEPLOYMENT_TARGET")
PY

  scons platform=ios target=$GODOT_TARGET arch=arm64 ios_simulator=no \
    use_lto=$USE_LTO debug_symbols=$DEBUG_SYMBOLS tools=no verbose=no
  popd >/dev/null

  # Re-detect after building
  LIB_DEV="$(find_lib "$GODOT_BIN" "libgodot.*ios.*release*.arm64*.a" || true)"
  [[ -n "$LIB_DEV" ]] || LIB_DEV="$(find_lib "$GODOT_BIN" "libgodot.*ios.*template*.arm64*.a" || true)"
fi

[[ -n "$LIB_DEV" ]] || die "Device library not found in $GODOT_BIN"
log "DEVICE lib: $LIB_DEV"

# =========================
# 3) Create ios_libgodot.xcframework (device-only)
# =========================
log "Creating ios_libgodot.xcframework (device-only)…"
rm -rf "$WORK/SwiftGodotKit/libgodot.xcframework"
xcodebuild -create-xcframework \
  -library "$LIB_DEV" -headers "$WORK/godot" \
  -output "$WORK/SwiftGodotKit/libgodot.xcframework"

[[ -d "$WORK/SwiftGodotKit/libgodot.xcframework" ]] || die "Failed to create libgodot.xcframework"

# =========================
# 4) Patch SwiftGodotKit & SwiftGodot to avoid ANY downloads
# =========================

# 4.a) Patch SwiftGodotKit: binaryTarget (main) → local path
KPKG="$WORK/SwiftGodotKit/Package.swift"
if grep -q "binaryTarget" "$KPKG"; then
  log "Patching SwiftGodotKit/Package.swift → binaryTarget(path: ./libgodot.xcframework)…"
  perl -0777 -pe 's#binaryTarget\s*\(\s*name:\s*"libgodot"[^)]*\)#binaryTarget(name: "libgodot", path: "./libgodot.xcframework")#s' -i "$KPKG"
  perl -0777 -pe 's#(name:\s*"libgodot"[^)]*?)url:\s*"[^"]*",\s*checksum:\s*"[^"]*"#\1path: "./libgodot.xcframework"#s' -i "$KPKG" || true
fi

# 4.b) Patch SwiftGodotKit: tests binaryTarget → local path
log "Patching SwiftGodotKit/Package.swift → libgodot_tests → local path…"
perl -0777 -pe 's#binaryTarget\s*\(\s*name:\s*"libgodot_tests"[^)]*\)#binaryTarget(name: "libgodot_tests", path: "./libgodot.xcframework")#s' -i "$KPKG" || true
perl -0777 -pe 's#(name:\s*"libgodot_tests"[^)]*?)url:\s*"[^"]*",\s*checksum:\s*"[^"]*"#\1path: "./libgodot.xcframework"#s' -i "$KPKG" || true

# 4.c) Optionally remove test targets to simplify resolution
log "Removing testTarget declarations from SwiftGodotKit (to avoid resolution)…"
#sed -i.bak '/testTarget\s*\(/d' "$KPKG" || true

# 4.d) Make SwiftGodot depend on local SwiftGodotKit by PATH
SGPKG="$WORK/SwiftGodot/Package.swift"
log "Rewriting SwiftGodot dependency on SwiftGodotKit → local path ../SwiftGodotKit…"
perl -0777 -pe 's#\.package\s*\(\s*url:\s*"https?://[^"]*SwiftGodotKit[^"]*",\s*(from|exact):\s*"[^"]*"\s*\)#.package(name: "SwiftGodotKit", path: "../SwiftGodotKit")#s' -i "$SGPKG"
perl -0777 -pe 's#\.package\s*\(\s*url:\s*"https?://[^"]*SwiftGodotKit[^"]*"\s*,\s*[^)]*\)#.package(name: "SwiftGodotKit", path: "../SwiftGodotKit")#s' -i "$SGPKG" || true
perl -0777 -pe 's#(SwiftGodotKit[",:][^)]*from:\s*)"[^"]*"#\1"'"$SWIFTGODOTKIT_TAG"'"#s' -i "$SGPKG" || true

# =========================
# 5) Build SwiftGodot.xcframework and SwiftGodotKit.xcframework (device-only)
# =========================

resolve_with_retries () {
  local SCHEME="$1"
  local PROJ_DIR="$2"
  for attempt in 1 2 3; do
    log "Resolving packages for ${SCHEME} (attempt ${attempt}/3)…"
    if xcodebuild -resolvePackageDependencies -scheme "$SCHEME" -destination "generic/platform=iOS" -quiet; then
      return 0
    fi
    sleep 2
  done
  die "Package resolution failed for ${SCHEME}"
}

# Replace the whole build_swiftpkg_xcframework function with this device-only build (no archive)
build_swiftpkg_xcframework () {
  local NAME="$1"
  local PROJ_DIR="$2"
  pushd "$PROJ_DIR" >/dev/null

  resolve_with_retries "$NAME" "$PROJ_DIR"

  local DERIVED="$WORK/DerivedData-$NAME"
  rm -rf "$DERIVED"

  log "Building $NAME (iOS device, arm64)…"
  xcodebuild -scheme "$NAME" -configuration Release \
    -destination "generic/platform=iOS" \
    -sdk iphoneos \
    -derivedDataPath "$DERIVED" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY="" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES EXCLUDED_ARCHS="i386 x86_64" \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    build

  local FW="$DERIVED/Build/Products/Release-iphoneos/$NAME.framework"
  [[ -d "$FW" ]] || die "Framework not found at: $FW"

  log "Creating $NAME.xcframework (device-only)…"
  xcodebuild -create-xcframework \
    -framework "$FW" \
    -output "$OUT/$NAME.xcframework"

  popd >/dev/null
}

# log "Building SwiftGodot.xcframework…"
# build_swiftpkg_xcframework "SwiftGodot" "$WORK/SwiftGodot"

# Llama solo a SwiftGodotKit:
log "Building SwiftGodotKit.xcframework…"
NAME="SwiftGodotKit"
PROJ_DIR="$WORK/SwiftGodotKit"
DERIVED="$WORK/DerivedData-$NAME"
rm -rf "$DERIVED"

pushd "$PROJ_DIR" >/dev/null
xcodebuild -resolvePackageDependencies \
  -scheme "$NAME" \
  -destination "generic/platform=iOS" \
  -quiet

xcodebuild -scheme "$NAME" -configuration Release \
  -destination "generic/platform=iOS" \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED" \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SKIP_INSTALL=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY="" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES EXCLUDED_ARCHS="i386 x86_64" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  build
popd >/dev/null

FW="$DERIVED/Build/Products/Release-iphoneos/$NAME.framework"
[[ -d "$FW" ]] || die "Framework not found at: $FW"
xcodebuild -create-xcframework -framework "$FW" -output "$OUT/$NAME.xcframework"
log "✅ Done. Artifacts at: $OUT"
ls -1 "$OUT" || true

echo "----------------------------------------------------------------"
echo "If your Podspec needs to vendor these frameworks, point it to:"
echo "  $OUT/SwiftGodot.xcframework"
echo "  $OUT/SwiftGodotKit.xcframework"
echo "Reminder: your RN lib should copy the .pck into the iOS app bundle."
echo "----------------------------------------------------------------"
