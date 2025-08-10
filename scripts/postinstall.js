// scripts/postinstall.js
const fs = require('fs');
const path = require('path');

function patchAndroidAppBuildGradle() {
    const app = path.join(process.cwd(), 'android', 'app', 'build.gradle');
    if (!fs.existsSync(app)) return;
    let s = fs.readFileSync(app, 'utf8');
    if (!s.includes('godot-pck.gradle')) {
        s = `apply from: "../../node_modules/react-native-godot-view/android/gradle-plugin/godot-pck.gradle"\n` + s;
    }
    if (!s.includes('org.godotengine:godot')) {
        s = s.replace(/dependencies\s*{/, `dependencies {\n    implementation("org.godotengine:godot:4.4.1.stable")`);
    }
    fs.writeFileSync(app, s);
    console.log('[react-native-godot-view] Android build.gradle parchado');
}

patchAndroidAppBuildGradle();
console.log('[react-native-godot-view] Recuerda añadir GodotHost a MainActivity (embed view) o usa startGodotActivity()');
