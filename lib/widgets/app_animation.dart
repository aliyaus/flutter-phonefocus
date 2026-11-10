import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppAnimation extends StatelessWidget {
  const AppAnimation({
    super.key,
    required this.assetPath,
    this.width = 200,
    this.height = 200,
    this.repeat = true,
  });

  final String assetPath;
  final double width;
  final double height;
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      repeat: repeat,
      decoder: (bytes) => LottieComposition.decodeZip(
        bytes,
        filePicker: (files) => files.firstWhere(
          (file) =>
              file.name.startsWith('animations/') &&
              file.name.endsWith('.json'),
        ),
      ),
    );
  }
}
