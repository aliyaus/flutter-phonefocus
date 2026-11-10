import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:phonefocus/settings/settings.dart';

import 'hand_detection.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  bool _lockInMode = false;
  final AudioCache _soundCache = AudioCache(prefix: 'assets/sounds/');
  final AudioPlayer _soundPlayer = AudioPlayer();
  late final Future<void> _soundReady;
  bool _isDarkMode = false;
  String _selectedSound = 'fahhhsound.mp3';

  @override
  void initState() {
    super.initState();
    _soundPlayer.audioCache = _soundCache;
    _soundReady = _preloadEnableSound();
  }

  void _setLockInMode(bool enabled) {
    setState(() {
      _lockInMode = enabled;
    });
  }

  void _setDarkMode(bool enabled) {
    setState(() {
      _isDarkMode = enabled;
    });
  }

  void _setSound(String sound) {
    setState(() {
      _selectedSound = sound;
    });
  }

  Future<void> _preloadEnableSound() async {
    try {
      await _soundCache.loadAll(['fahhhsound.mp3', 'getouttt.mp3']);
    } catch (error) {
      debugPrint('Unable to cache enable sound: $error');
    }
  }

  Future<void> _playEnableSound() async {
    try {
      await _soundReady;
      if (!mounted) return;
      await _soundPlayer.stop();
      await _soundPlayer.play(AssetSource(_selectedSound));
    } catch (error) {
      debugPrint('Unable to play enable sound: $error');
    }
  }

  // potential enhancements
  // 1. gyroscope pick-up detection
  // 3. add vibrations when phone is picked up
  // 4. background hand detection
  // 5. settings screen to configure hand detection, vibrations, ect.
  // 6. pomodoro alarm based timer
  // 7. eye tracking -> if you look at the phone and are super close it will play the sound
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _lockInMode ? 'Turn off lock in mode' : 'Start Lock in mode',
              ),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Settings(
                          onDarkModeChanged: _setDarkMode,
                          selectedSound: _selectedSound,
                          onSoundChanged: _setSound,
                        ),
                      ),
                    );
                  },
                  child: Text('Settings'),
                ),
              ),
              Switch(value: _lockInMode, onChanged: _setLockInMode),
              if (_lockInMode)
                SizedBox(
                  width: 240,
                  height: 320,
                  child: HandDetectionView(onHandDetection: _playEnableSound),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
