// scripts/postinstall.js
/*
  Parches automáticos para Android:
  - Aplica el gradle script (godot-pck.gradle) en app (Groovy/KTS)
  - Añade dependencias en app: implementation("group:artifact:version")
  - Garantiza mavenCentral() en android/settings.gradle (Groovy/KTS)
  - Genera un log de verificación en android/.godot-postinstall.log
*/
const fs = require('fs');
const path = require('path');

const PKG_NAME = 'react-native-godot-view';

const DEPENDENCIES_TO_ADD = [
    'org.godotengine:godot:4.4.1.stable',
    // Añade más coordenadas si necesitas:
    // 'androidx.fragment:fragment:1.8.2',
];

const log = (m) => console.log(`[${PKG_NAME}] ${m}`);
const warn = (m) => console.warn(`[${PKG_NAME}] ⚠️ ${m}`);
const error = (m) => console.error(`[${PKG_NAME}] ❌ ${m}`);

function getProjectRoot() {
    const initCwd = process.env.INIT_CWD;
    if (initCwd && fs.existsSync(initCwd)) return initCwd;
    return path.resolve(__dirname, '..', '..');
}

function writeIfChanged(file, before, after) {
    if (before !== after) {
        fs.writeFileSync(file, after, 'utf8');
        return true;
    }
    return false;
}

function ensureDependenciesBlock(content) {
    const depOpen = /(^|\n)(\s*)dependencies\s*\{/m;
    if (depOpen.test(content)) return content;
    return `${content}\n\ndependencies {\n}\n`;
}

function addDependenciesLines(content, deps) {
    let out = content;
    const depOpen = /^(\s*)dependencies\s*\{/m;

    deps.forEach((coord) => {
        const already = new RegExp(coord.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).test(out);
        if (already) {
            log(`Dependencia ya presente: ${coord} (skip)`);
            return;
        }
        const m = out.match(depOpen);
        if (m) {
            const indent = m[1] || '';
            const line = `${indent}    implementation("${coord}")`;
            out = out.replace(depOpen, (open) => `${open}\n${line}`);
            log(`Añadida dependencia: ${coord}`);
        } else {
            warn(`No se pudo localizar el bloque dependencies para añadir: ${coord}`);
        }
    });

    return out;
}

function ensureGodotPckApply(content, isKts) {
    if (content.includes('godot-pck.gradle')) {
        log('apply godot-pck.gradle ya presente');
        return content;
    }
    const applyLine = isKts
        ? `apply(from = "../../node_modules/${PKG_NAME}/android/gradle-plugin/godot-pck.gradle")`
        : `apply from: "../../node_modules/${PKG_NAME}/android/gradle-plugin/godot-pck.gradle"`;

    log('Añadido apply godot-pck.gradle en app');
    return `${applyLine}\n${content}`;
}

function patchAppBuildGradle(projectRoot, result) {
    const groovy = path.join(projectRoot, 'android', 'app', 'build.gradle');
    const kts = path.join(projectRoot, 'android', 'app', 'build.gradle.kts');

    const file = fs.existsSync(groovy) ? groovy : (fs.existsSync(kts) ? kts : null);
    if (!file) {
        warn('No se encontró app/build.gradle(.kts).');
        result.appGradleFound = false;
        return;
    }
    result.appGradleFound = true;

    const isKts = file.endsWith('.kts');
    let src = fs.readFileSync(file, 'utf8');
    let out = src;

    // apply plugin
    out = ensureGodotPckApply(out, isKts);

    // asegurar bloque dependencies
    out = ensureDependenciesBlock(out);

    // añadir dependencias
    out = addDependenciesLines(out, DEPENDENCIES_TO_ADD);

    // escribir si cambió
    writeIfChanged(file, src, out);

    // verificación final (re-lee y checa)
    const final = fs.readFileSync(file, 'utf8');
    result.applyPluginOK = final.includes('godot-pck.gradle');
    result.depsOK = DEPENDENCIES_TO_ADD.every((coord) => final.includes(coord));
    result.appGradlePath = file;
}

function ensureMavenCentralInSettings(projectRoot, result) {
    const groovy = path.join(projectRoot, 'android', 'settings.gradle');
    const kts = path.join(projectRoot, 'android', 'settings.gradle.kts');
    const file = fs.existsSync(groovy) ? groovy : (fs.existsSync(kts) ? kts : null);

    if (!file) {
        warn('No se encontró settings.gradle(.kts).');
        result.settingsFound = false;
        return;
    }
    result.settingsFound = true;

    let src = fs.readFileSync(file, 'utf8');
    let out = src;

    const hasDRM = /dependencyResolutionManagement\s*\{[\s\S]*?\}/m.test(out);
    if (hasDRM) {
        out = out.replace(/dependencyResolutionManagement\s*\{([\s\S]*?)\}/m, (full) => {
            if (/repositories\s*\{[\s\S]*?\}/m.test(full)) {
                if (!/mavenCentral\s*\(\s*\)/.test(full)) {
                    return full.replace(/repositories\s*\{\s*/m, (r) => `${r}        mavenCentral()\n        `);
                }
                return full;
            } else {
                const insert = `repositories {\n        google()\n        mavenCentral()\n    }`;
                return full.replace(/\{\s*/, `{\n    ${insert}\n    `);
            }
        });
    } else {
        out += `

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
    }
}
`;
    }

    writeIfChanged(file, src, out);

    const final = fs.readFileSync(file, 'utf8');
    result.mavenCentralOK = /mavenCentral\s*\(\s*\)/.test(final);
    result.settingsPath = file;
}

function writeSummary(projectRoot, result) {
    const logPath = path.join(projectRoot, 'android', '.godot-postinstall.log');
    const lines = [];
    lines.push(`[${PKG_NAME}] Postinstall summary`);
    lines.push(`projectRoot: ${projectRoot}`);
    lines.push(`appGradle: ${result.appGradleFound ? result.appGradlePath : 'NOT FOUND'}`);
    lines.push(`settings: ${result.settingsFound ? result.settingsPath : 'NOT FOUND'}`);
    lines.push(`applyPlugin: ${result.applyPluginOK ? 'PASS' : 'FAIL'}`);
    lines.push(`dependencies: ${result.depsOK ? 'PASS' : 'FAIL'} (${(result.addedDeps || DEPENDENCIES_TO_ADD).join(', ')})`);
    lines.push(`mavenCentral: ${result.mavenCentralOK ? 'PASS' : 'FAIL'}`);
    lines.push(`timestamp: ${new Date().toISOString()}`);
    try {
        fs.writeFileSync(logPath, lines.join('\n') + '\n', 'utf8');
        log(`Resumen escrito en ${path.relative(projectRoot, logPath)}`);
    } catch (e) {
        warn(`No se pudo escribir el resumen: ${e?.message || e}`);
    }

    // También escupe un resumen a consola
    log('Resumen: ' +
        `plugin=${result.applyPluginOK ? 'OK' : 'NO'}, ` +
        `deps=${result.depsOK ? 'OK' : 'NO'}, ` +
        `mavenCentral=${result.mavenCentralOK ? 'OK' : 'NO'}`);
}

function main() {
    const result = {};
    try {
        const projectRoot = getProjectRoot();

        // Nota: en workspaces o con link: los lifecycle scripts pueden no ejecutarse.
        patchAppBuildGradle(projectRoot, result);
        ensureMavenCentralInSettings(projectRoot, result);
        writeSummary(projectRoot, result);

        log('Postinstall finalizado. Si cambiaste Gradle, ejecuta: cd android && ./gradlew clean');

        // Heurística: si nada se pudo parchear, probablemente el postinstall no se ejecutó en el host (link:)
        if (!result.appGradleFound && !result.settingsFound) {
            warn('No se encontraron archivos Android del proyecto. Si usas "link:" o un monorepo, ejecuta este script manualmente en el proyecto app.');
        }
    } catch (e) {
        error(`Error durante postinstall: ${e?.message || e}`);
    }
}

main();
