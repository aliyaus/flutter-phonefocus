import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:phonefocus/settings/settings.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'hand_detection.dart';
import 'widgets/app_animation.dart';

const double pickupThreshold = 1.2;
const Duration restDuration = Duration(seconds: 1);
const Duration samplingPeriod = Duration(milliseconds: 40);

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _lockInMode = false;
  final AudioCache _soundCache = AudioCache(prefix: 'assets/sounds/');
  final AudioPlayer _soundPlayer = AudioPlayer();
  late final Future<void> _soundReady;
  bool _isDarkMode = false;
  String _selectedSound = 'fahhhsound.mp3';
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  Timer? _restTimer;
  bool _isPickedUp = false;
  bool _soundPending = false;
  int _soundGeneration = 0;
  Future<void> _audioCommands = Future<void>.value();
  String? _motionError;

  @override
  void initState() {
    super.initState();
    _soundPlayer.audioCache = _soundCache;
    _soundReady = _preloadEnableSound();
  }

  void _startListening() {
    _stopListening();

    void onError(Object error) {
      if (!mounted || !_lockInMode) return;
      debugPrint('Motion detection unavailable: $error');
      _stopMotionAndSound();
      setState(() => _motionError = 'Motion detection is unavailable.');
    }

    try {
      _accelerometerSubscription =
          userAccelerometerEventStream(samplingPeriod: samplingPeriod).listen((
            event,
          ) {
            if (!mounted || !_lockInMode) return;
            // User acceleration excludes gravity and is measured in m/s².
            final acceleration = sqrt(
              event.x * event.x + event.y * event.y + event.z * event.z,
            );

            // Ignore sensor readings below pickupThreshold
            if (acceleration < pickupThreshold) return;

            _restTimer?.cancel();
            _restTimer = Timer(restDuration, () {
              _onMovementChanged(false);
            });
            if (!_isPickedUp) _onMovementChanged(true);
          }, onError: onError);
    } catch (error) {
      onError(error);
    }
  }

  void _stopListening() {
    unawaited(_accelerometerSubscription?.cancel());
    _accelerometerSubscription = null;
    _restTimer?.cancel();
    _restTimer = null;
  }

  void _setLockInMode(bool enabled) {
    setState(() {
      _lockInMode = enabled;
      _motionError = null;
    });
    if (enabled) {
      _startListening();
    } else {
      _stopMotionAndSound();
    }
  }

  void _disableLockInMode() {
    _setLockInMode(false);
  }

  void _onMovementChanged(bool moving) {
    if (!mounted || !_lockInMode) return;
    setState(() => _isPickedUp = moving);
    if (moving) {
      unawaited(_playEnableSound());
    } else {
      _stopSound();
    }
  }

  void _queueAudio(Future<void> Function() action) {
    _audioCommands = _audioCommands.then((_) => action()).catchError((
      Object error,
    ) {
      debugPrint('Unable to update sound: $error');
    });
  }

  void _stopSound() {
    _soundGeneration++;
    _queueAudio(() => _soundPlayer.stop());
  }

  void _stopMotionAndSound() {
    _stopListening();
    _isPickedUp = false;
    _stopSound();
  }

  @override
  void dispose() {
    _stopMotionAndSound();
    _queueAudio(() => _soundPlayer.dispose());
    super.dispose();
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

  Future<void> _playEnableSound() {
    if (_soundPending || !_lockInMode) {
      return Future<void>.value();
    }
    _soundPending = true;
    final generation = _soundGeneration;
    _queueAudio(() async {
      try {
        await _soundReady;
        if (!mounted || !_lockInMode || generation != _soundGeneration) {
          return;
        }
        await _soundPlayer.setReleaseMode(
          _isPickedUp ? ReleaseMode.loop : ReleaseMode.release,
        );
        if (_soundPlayer.state != PlayerState.playing) {
          await _soundPlayer.play(AssetSource(_selectedSound));
        }
      } finally {
        _soundPending = false;
        // A new session may have started while an older play was queued.
        if (generation != _soundGeneration &&
            mounted &&
            _lockInMode &&
            _isPickedUp) {
          unawaited(_playEnableSound());
        }
      }
    });
    return _audioCommands;
  }

  // potential enhancements
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
              StreamBuilder<PlayerState>(
                stream: _soundPlayer.onPlayerStateChanged,
                initialData: _soundPlayer.state,
                builder: (context, snapshot) => AppAnimation(
                  assetPath: snapshot.data == PlayerState.playing
                      ? 'assets/animations/angry.lottie'
                      : 'assets/animations/default.lottie',
                ),
              ),
              Text(
                _lockInMode ? 'Turn off lock in mode' : 'Start Lock in mode',
              ),
              Switch(value: _lockInMode, onChanged: _setLockInMode),
              if (_lockInMode)
                Text(
                  _motionError ??
                      (_isPickedUp
                          ? 'Phone moving — put it down to stop the sound'
                          : 'Pickup detection is active'),
                ),
              if (_lockInMode)
                SizedBox(
                  width: 240,
                  height: 320,
                  child: HandDetectionView(onHandDetection: _playEnableSound),
                ),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    _disableLockInMode();
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
            ],
          ),
        ),
      ),
    );
  }
}
