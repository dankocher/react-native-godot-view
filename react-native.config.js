// react-native.config.js
module.exports = {
    dependency: {
        platforms: {
            android: {
                packageImportPath: 'import com.rngodotview.GodotBridgePackage;',
                packageInstance: 'new GodotBridgePackage()',
            },
            ios: {},
        },
        assets: [], // no publicamos assets desde el paquete; el .pck vive en el proyecto del usuario
    },
};
