import {ComponentType} from 'react';
import {ViewProps, NativeSyntheticEvent} from 'react-native';

export type GodotEvent = NativeSyntheticEvent<{ data: string }>;

export interface GodotViewProps extends ViewProps {
    pckName?: string;
    onGodotEvent?: (e: GodotEvent) => void;
}

export const GodotView: ComponentType<GodotViewProps>;
export const GodotBridge: { send(json: string): void };
