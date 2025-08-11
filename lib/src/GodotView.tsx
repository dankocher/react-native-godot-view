import React from 'react';
import {requireNativeComponent, ViewProps, NativeSyntheticEvent} from 'react-native';

export type GodotEvent = NativeSyntheticEvent<{ data: string }>;
export type GodotViewProps = ViewProps & { pckName?: string; onGodotEvent?: (e: GodotEvent) => void; };
const RNGodotView = requireNativeComponent<GodotViewProps>('RNGodotView');
export default RNGodotView;
