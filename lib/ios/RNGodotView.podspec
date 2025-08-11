Pod::Spec.new do |s|
  s.name         = 'RNGodotView'
  s.version      = '0.1.0'
  s.summary      = 'React Native view to embed Godot on iOS with an event bridge.'
  s.license      = { :type => 'MIT' }
  s.authors      = { 'You' => 'dev@example.com' }
  s.homepage     = 'https://example.com/rn-godot-view'
  s.source       = { :git => 'https://example.com/rn-godot-view.git', :tag => s.version.to_s }

  s.platforms    = { :ios => '13.0' }
  s.source_files = 'ios/**/*.{swift,m}'

  s.swift_version = '5.9'
  s.dependency 'React-Core'

  # Si empaquetas frameworks de Godot, decláralos aquí:
  # s.vendored_frameworks = 'ios/Vendor/GodotEngine.xcframework', 'ios/Vendor/GodotKit.xcframework'
  # s.libraries = 'c++'

  # Fase: copiar el primer .pck encontrado en src/assets al bundle de app
  s.script_phase = {
    :name => 'Copy Godot .pck',
    :execution_position => :before_compile,
    :shell_path => '/bin/sh',
    :script => <<-'SH'
set -euo pipefail
ROOT_DIR="${PROJECT_DIR%/ios}"
ASSETS_DIR="${ROOT_DIR}/src/assets"
DEST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

mkdir -p "${DEST}"

if [ -d "${ASSETS_DIR}" ]; then
  PCK_FILE=$(ls -1 "${ASSETS_DIR}"/*.pck 2>/dev/null | head -n 1 || true)
  if [ -n "${PCK_FILE}" ]; then
    cp -f "${PCK_FILE}" "${DEST}/"
    echo "[react-native-godot-view] Copied $(basename "${PCK_FILE}") → Resources"
  else
    echo "[react-native-godot-view] No *.pck found under src/assets"
  fi
else
  echo "[react-native-godot-view] src/assets not found"
fi
SH
  }
end
