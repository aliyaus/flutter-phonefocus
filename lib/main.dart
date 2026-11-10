import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:phonefocus/settings/settings.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'hand_detection.dart';
import 'widgets/app_animation.dart';
import 'widgets/detection_message.dart';

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
  bool _showLivePreview = true;
  bool _handDetection = true;
  bool _pickupDetection = true;
  bool _eyeDetection = true;
  String _selectedSound = 'fahhhsound.mp3';
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  Timer? _restTimer;
  bool _isPickedUp = false;
  bool _isHandDetected = false;
  bool _areEyesClose = false;

  bool get _shouldPlaySound =>
      _lockInMode && (_isPickedUp || _isHandDetected || _areEyesClose);

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
    if (!_pickupDetection) return;

    void onError(Object error) {
      if (!mounted || !_lockInMode) return;
      debugPrint('Motion detection unavailable: $error');
      _stopListening();
      setState(() {
        _isPickedUp = false;
        _motionError = 'Motion detection is unavailable.';
      });
      _updateDetectionSound();
    }

    try {
      _accelerometerSubscription =
          userAccelerometerEventStream(samplingPeriod: samplingPeriod).listen((
            event,
          ) {
            if (!mounted || !_lockInMode || !_pickupDetection) return;
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
      _isPickedUp = false;
      _isHandDetected = false;
      _areEyesClose = false;
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
    if (!mounted || !_lockInMode || !_pickupDetection) return;
    setState(() => _isPickedUp = moving);
    _updateDetectionSound();
  }

  void _onHandDetectionChanged(bool detected) {
    if (!mounted || !_lockInMode || !_handDetection) return;
    setState(() => _isHandDetected = detected);
    _updateDetectionSound();
  }

  void _onEyesCloseChanged(bool close) {
    if (!mounted || !_lockInMode || !_eyeDetection) return;
    setState(() => _areEyesClose = close);
    _updateDetectionSound();
  }

  void _updateDetectionSound() {
    if (_shouldPlaySound) {
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
    _isHandDetected = false;
    _areEyesClose = false;
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

  void _setLivePreview(bool enabled) {
    setState(() => _showLivePreview = enabled);
  }

  void _setHandDetection(bool enabled) {
    setState(() {
      _handDetection = enabled;
      // Changing camera detectors recreates HandDetectionView.
      _isHandDetected = false;
      _areEyesClose = false;
    });
    _updateDetectionSound();
  }

  void _setPickupDetection(bool enabled) {
    setState(() {
      _pickupDetection = enabled;
      _motionError = null;
      _isPickedUp = false;
    });
    if (!enabled) {
      _stopListening();
    } else if (_lockInMode) {
      _startListening();
    }
    _updateDetectionSound();
  }

  void _setEyeDetection(bool enabled) {
    setState(() {
      _eyeDetection = enabled;
      _isHandDetected = false;
      _areEyesClose = false;
    });
    _updateDetectionSound();
  }

  Future<void> _preloadEnableSound() async {
    try {
      await _soundCache.loadAll(['fahhhsound.mp3', 'getouttt.mp3']);
    } catch (error) {
      debugPrint('Unable to cache enable sound: $error');
    }
  }

  Future<void> _playEnableSound() {
    if (_soundPending || !_shouldPlaySound) {
      return Future<void>.value();
    }
    _soundPending = true;
    final generation = _soundGeneration;
    _queueAudio(() async {
      try {
        await _soundReady;
        if (!mounted || !_shouldPlaySound || generation != _soundGeneration) {
          return;
        }
        await _soundPlayer.setReleaseMode(ReleaseMode.loop);
        if (_soundPlayer.state != PlayerState.playing) {
          await _soundPlayer.play(AssetSource(_selectedSound));
        }
      } finally {
        _soundPending = false;
        // A new session may have started while an older play was queued.
        if (generation != _soundGeneration && mounted && _shouldPlaySound) {
          unawaited(_playEnableSound());
        }
      }
    });
    return _audioCommands;
  }

  // potential enhancements
  // 4. background detection
  // 6. pomodoro alarm based timer
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
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
                if (_lockInMode) ...[
                  if (_motionError != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(_motionError!, textAlign: TextAlign.center),
                    ),
                  if (_isHandDetected)
                    const DetectionMessage(
                      message: 'Hands off. Stay in your flow.',
                    ),
                  if (_areEyesClose)
                    const DetectionMessage(
                      message: 'Take a step back. Refocus.',
                    ),
                  if (_isPickedUp)
                    const DetectionMessage(
                      message: 'Phone down. You’ve got this.',
                    ),
                ],
                if (_lockInMode && (_handDetection || _eyeDetection))
                  SizedBox(
                    width: 240,
                    height: _showLivePreview ? 320 : null,
                    child: HandDetectionView(
                      key: ValueKey((_handDetection, _eyeDetection)),
                      enableHandDetection: _handDetection,
                      enableEyeDetection: _eyeDetection,
                      onHandDetectionChanged: _onHandDetectionChanged,
                      onEyesCloseChanged: _onEyesCloseChanged,
                      showPreview: _showLivePreview,
                    ),
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
                            showLivePreview: _showLivePreview,
                            onLivePreviewChanged: _setLivePreview,
                            handDetection: _handDetection,
                            onHandDetectionChanged: _setHandDetection,
                            pickupDetection: _pickupDetection,
                            onPickupDetectionChanged: _setPickupDetection,
                            eyeDetection: _eyeDetection,
                            onEyeDetectionChanged: _setEyeDetection,
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
      ),
    );
  }
}
