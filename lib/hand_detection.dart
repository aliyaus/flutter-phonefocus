import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hand_detection/hand_detection.dart';

class HandDetectionView extends StatefulWidget {
  final Future<void> Function() onHandDetection;

  const HandDetectionView({super.key, required this.onHandDetection});

  @override
  State<HandDetectionView> createState() => _HandDetectionViewState();
}

class _HandDetectionViewState extends State<HandDetectionView> {
  CameraController? _camera;
  HandDetector? _detector;
  late final Future<void> _initialization;
  bool _processing = false;
  bool _ready = false;
  List<Hand> _hands = [];
  double _widthRatio = 0;
  Size? _imageSize;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      _detector = await HandDetector.create(
        mode: HandMode.boxesAndLandmarks,
        maxDetections: 2,
        enableGestures: true,
        gestureMinConfidence: 0.5,
        performanceConfig: const PerformanceConfig.xnnpack(),
      );
      if (!mounted) return;

      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) throw StateError('No cameras available');

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _camera!.initialize();
      if (!mounted) return;

      await _camera!.startImageStream(_processCameraImage);
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to start camera: $error');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!mounted || _processing) return;
    _processing = true;
    try {
      final rotation = rotationForFrame(
        width: image.width,
        height: image.height,
        sensorOrientation: _camera!.description.sensorOrientation,
        isFrontCamera:
            _camera!.description.lensDirection == CameraLensDirection.front,
        deviceOrientation: _camera!.value.deviceOrientation,
      );
      final hands = await _detector!.detectFromCameraImage(
        image,
        rotation: rotation,
        maxDim: 640,
      );
      final widthRatio = hands.fold<double>(0, (largest, hand) {
        final ratio = hand.boundingBox.width / hand.imageWidth;
        return ratio > largest ? ratio : largest;
      });
      final hasOpenPalmGesture = hands.any(
        (hand) => hand.gesture?.type == GestureType.openPalm,
      );
      if (mounted && hasOpenPalmGesture) {
        widget.onHandDetection();
      }
      if (mounted) {
        setState(() {
          _hands = hands;
          _widthRatio = widthRatio;
          _imageSize = detectionSize(
            width: image.width,
            height: image.height,
            rotation: rotation,
            maxDim: 640,
          );
        });
      }
    } catch (error) {
      debugPrint('Hand detection failed: $error');
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    // Wait for startup so toggling off during initialization also releases it.
    _initialization.then((_) async {
      await _camera?.dispose();
      await _detector?.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (!_ready) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Text('Hands detected: ${_hands.length}'),
        Text(
          'Width ratio: ${_widthRatio.toStringAsFixed(2)} '
          '(${(_widthRatio * 100).toStringAsFixed(1)}%)',
        ),
        Expanded(
          child: Center(
            child: CameraPreview(
              _camera!,
              child: _imageSize == null
                  ? null
                  : CustomPaint(
                      painter: CameraHandOverlayPainter(
                        hands: _hands,
                        imageSize: _imageSize!,
                        mirrorHorizontally:
                            (defaultTargetPlatform == TargetPlatform.android &&
                                _camera!.description.lensDirection ==
                                    CameraLensDirection.front) ||
                            defaultTargetPlatform == TargetPlatform.windows,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
