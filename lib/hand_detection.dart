import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart' as face;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_litert/flutter_litert.dart' show CoverFitTransform;
import 'package:hand_detection/hand_detection.dart';

// A larger distance between the eyes in the image means a closer face.
const double closeEyeDistanceRatio = 0.25;
const int detectionMaxDimension = 640;
const int maxHandDetections = 2;
const double gestureMinConfidence = 0.5;
const double eyeMarkerRadius = 4;

class HandDetectionView extends StatefulWidget {
  final ValueChanged<bool> onHandDetectionChanged;
  final ValueChanged<bool> onEyesCloseChanged;
  final bool showPreview;
  final bool enableHandDetection;
  final bool enableEyeDetection;

  const HandDetectionView({
    super.key,
    required this.onHandDetectionChanged,
    required this.onEyesCloseChanged,
    this.showPreview = true,
    this.enableHandDetection = true,
    this.enableEyeDetection = true,
  });

  @override
  State<HandDetectionView> createState() => _HandDetectionViewState();
}

class _HandDetectionViewState extends State<HandDetectionView> {
  CameraController? _camera;
  HandDetector? _detector;
  face.FaceDetector? _faceDetector;
  late final Future<void> _initialization;
  bool _processing = false;
  bool _ready = false;
  List<Hand> _hands = [];
  List<face.Face> _faces = [];
  double _widthRatio = 0;
  bool _eyesClose = false;
  bool _handDetected = false;
  Size? _imageSize;
  String? _error;
  String? _handError;
  String? _eyeError;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (widget.enableHandDetection) {
        _detector = await HandDetector.create(
          mode: HandMode.boxesAndLandmarks,
          maxDetections: maxHandDetections,
          enableGestures: true,
          gestureMinConfidence: gestureMinConfidence,
          performanceConfig: const PerformanceConfig.xnnpack(),
        );
      }
      if (!mounted) return;

      if (widget.enableEyeDetection) {
        _faceDetector = await face.FaceDetector.create(
          model: face.FaceDetectionModel.frontCamera,
          performanceConfig: const PerformanceConfig.xnnpack(),
        );
      }
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
      setState(() {
        _imageSize = detectionSize(
          width: image.width,
          height: image.height,
          rotation: rotation,
          maxDim: detectionMaxDimension,
        );
      });
      // Each detector publishes its own results. A slow or failing face
      // detector must not prevent successful hand detections from being drawn.
      await Future.wait([
        if (widget.enableHandDetection) _processHands(image, rotation),
        if (widget.enableEyeDetection) _processFaces(image, rotation),
      ]);
    } catch (error, stackTrace) {
      debugPrint('Camera detection failed: $error\n$stackTrace');
    } finally {
      _processing = false;
    }
  }

  Future<void> _processHands(
    CameraImage image,
    CameraFrameRotation? rotation,
  ) async {
    try {
      final hands = await _detector!.detectFromCameraImage(
        image,
        rotation: rotation,
        maxDim: detectionMaxDimension,
      );
      if (!mounted) return;
      final widthRatio = hands.fold<double>(0, (largest, hand) {
        final ratio = hand.boundingBox.width / hand.imageWidth;
        return ratio > largest ? ratio : largest;
      });
      setState(() {
        _hands = hands;
        _widthRatio = widthRatio;
        _handError = null;
      });
      _reportHandDetection(
        hands.any((hand) => hand.gesture?.type == GestureType.openPalm),
      );
    } catch (error, stackTrace) {
      debugPrint('Hand detection failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _hands = [];
        _widthRatio = 0;
        _handError = error.toString();
      });
      _reportHandDetection(false);
    }
  }

  Future<void> _processFaces(
    CameraImage image,
    CameraFrameRotation? rotation,
  ) async {
    try {
      final faces = await _faceDetector!.detectFacesFromCameraImage(
        image,
        rotation: rotation,
        mode: face.FaceDetectionMode.standard,
        maxDim: detectionMaxDimension,
      );
      if (!mounted) return;
      final eyesClose = faces.any((detectedFace) {
        final leftEye = detectedFace.landmarks.leftEye;
        final rightEye = detectedFace.landmarks.rightEye;
        if (leftEye == null || rightEye == null) return false;

        final eyeDistance =
            (Offset(leftEye.x, leftEye.y) - Offset(rightEye.x, rightEye.y))
                .distance;
        return eyeDistance / detectedFace.originalSize.width >=
            closeEyeDistanceRatio;
      });
      setState(() {
        _faces = faces;
        _eyeError = null;
      });
      _reportEyesClose(eyesClose);
    } catch (error, stackTrace) {
      debugPrint('Eye detection failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _faces = [];
        _eyeError = error.toString();
      });
      _reportEyesClose(false);
    }
  }

  void _reportHandDetection(bool detected) {
    if (_handDetected == detected) return;
    _handDetected = detected;
    widget.onHandDetectionChanged(detected);
  }

  void _reportEyesClose(bool close) {
    if (_eyesClose == close) return;
    setState(() => _eyesClose = close);
    widget.onEyesCloseChanged(close);
  }

  @override
  void dispose() {
    // Wait for startup so toggling off during initialization also releases it.
    _initialization.then((_) async {
      await _camera?.dispose();
      await _detector?.dispose();
      await _faceDetector?.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (!_ready) return const Center(child: CircularProgressIndicator());

    final mirrorHorizontally =
        (defaultTargetPlatform == TargetPlatform.android &&
            _camera!.description.lensDirection == CameraLensDirection.front) ||
        defaultTargetPlatform == TargetPlatform.windows;

    return Column(
      children: [
        if (_handError != null)
          Tooltip(
            message: _handError!,
            child: const Text(
              'Hand detection failed',
              style: TextStyle(color: Colors.red),
            ),
          ),
        if (_eyeError != null)
          Tooltip(
            message: _eyeError!,
            child: const Text(
              'Eye detection failed',
              style: TextStyle(color: Colors.red),
            ),
          ),
        if (kDebugMode) ...[
          Text('Hands detected: ${_hands.length}'),
          Text('Faces detected: ${_faces.length}'),
          Text(
            _eyesClose
                ? 'Eyes are too close'
                : 'Eye proximity detection active',
          ),
          Text(
            'Width ratio: ${_widthRatio.toStringAsFixed(2)} '
            '(${(_widthRatio * 100).toStringAsFixed(1)}%)',
          ),
        ],
        if (widget.showPreview)
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
                          mirrorHorizontally: mirrorHorizontally,
                        ),
                        foregroundPainter: _EyeOverlayPainter(
                          faces: _faces,
                          mirrorHorizontally: mirrorHorizontally,
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EyeOverlayPainter extends CustomPainter {
  const _EyeOverlayPainter({
    required this.faces,
    required this.mirrorHorizontally,
  });

  final List<face.Face> faces;
  final bool mirrorHorizontally;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.cyanAccent;
    for (final detectedFace in faces) {
      final transform = CoverFitTransform.cover(
        sourceWidth: detectedFace.originalSize.width,
        sourceHeight: detectedFace.originalSize.height,
        viewWidth: size.width,
        viewHeight: size.height,
        mirror: mirrorHorizontally,
      );
      for (final eye in [
        detectedFace.landmarks.leftEye,
        detectedFace.landmarks.rightEye,
      ]) {
        if (eye == null) continue;
        canvas.drawCircle(transform.map(eye.x, eye.y), eyeMarkerRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EyeOverlayPainter oldDelegate) =>
      faces != oldDelegate.faces ||
      mirrorHorizontally != oldDelegate.mirrorHorizontally;
}
