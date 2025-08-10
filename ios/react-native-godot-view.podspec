Pod::Spec.new do |s|
  s.name         = "react-native-godot-view"
  s.version      = "0.1.0"
  s.summary      = "Embed Godot runtime in a React Native view with event bridge"
  s.homepage     = "https://npmjs.com/package/react-native-godot-view"
  s.license      = { :type => "MIT" }
  s.authors      = { "You" => "droque123@gmail.com" }
  s.platform     = :ios, "14.0"
  s.source       = { :git => "https://github.com/dankocher/react-native-godot-view.git", :tag => s.version.to_s }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  # Frameworks vendorizados incluidos en el paquete
  s.vendored_frameworks = [
    "ios/Vendor/SwiftGodot.xcframework",
    "ios/Vendor/SwiftGodotKit.xcframework"
  ]

  s.frameworks = "Metal", "MetalKit"
  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS" => "$(inherited) -lc++",
    "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES" => "YES"
  }

  # Script phase que copia el primer *.pck de PROJECT_ROOT/src/assets al bundle
  s.script_phase = {
    :name => "[react-native-godot-view] Copy PCK",
    :execution_position => :before_compile,
    :script => <<-SCRIPT
ROOT="$PROJECT_DIR/.."
ASSETS="$ROOT/src/assets"
DEST="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$DEST"
PCK=$(ls "$ASSETS"/*.pck 2>/dev/null | head -n 1)
if [ -f "$PCK" ]; then
  cp "$PCK" "$DEST/"
  echo "[react-native-godot-view] Copiado $(basename "$PCK") → bundle"
else
  echo "[react-native-godot-view] No se encontró *.pck en src/assets"
fi
SCRIPT
  }
end
