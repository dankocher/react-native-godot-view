import {Alert, Button, StatusBar, StyleSheet, View} from 'react-native';
import {GodotBridge, GodotView} from 'react-native-godot-view';

function App() {

    const handleGodotEvent = (e: any) => {
        Alert.alert('Godot event:', e.nativeEvent.data);
    }

    return (
        <View style={styles.container}>
            <StatusBar hidden={true}/>
            <GodotView style={StyleSheet.absoluteFill} onGodotEvent={handleGodotEvent} />
            <View style={styles.buttonContainer}>
                <Button title={"Send message to godot"} onPress={() => GodotBridge.send('Hello from React Native!')}/>
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    buttonContainer: {
        position: 'absolute',
        bottom: 20,
        left: 20,
        right: 20,
    }
});

export default App;
