import {NativeModules} from 'react-native';

export const GodotBridge = NativeModules.GodotBridge as {
    send(json: string): void
};
