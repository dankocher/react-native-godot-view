Pod::Spec.new do |s|
  s.name         = "react-native-godot-view"
  s.version      = "0.1.0"
  s.summary      = "Embed Godot in a React Native view with an event bridge"
  s.homepage     = "https://github.com/your-org/react-native-godot-view"
  s.license      = { :type => "MIT" }
  s.authors      = { "You" => "droque123@gmail.com" }
  s.platform     = :ios, "13.0"
  s.source       = { :path => "." }
  s.source_files = "ios/**/*.{h,m,mm,swift}"
  s.vendored_frameworks = [
    "ios/Vendor/SwiftGodot.xcframework",
    "ios/Vendor/SwiftGodotKit.xcframework"
  ]
  s.frameworks = "Metal", "MetalKit"
  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS" => "$(inherited) -lc++",
    "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES" => "YES"
  }
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
  echo "[react-native-godot-view] Copied $(basename "$PCK") → bundle"
else
  echo "[react-native-godot-view] No *.pck found under src/assets"
fi
SCRIPT
  }
end
