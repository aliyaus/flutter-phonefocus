# phonefocus

Enable lock in mode to open the front camera and draw the detected hands' joints
and finger connections over the live preview. Detection runs on device, tracks
up to two hands, and stops when lock in mode is disabled or the app backgrounds.

Requires Flutter 3.47.5 or newer (Dart 3.10+) for `hand_detection` 4.3.1 and its
native dependencies. iOS requires version 15 or newer. After upgrading Flutter,
run `flutter clean` and `flutter pub get` before building.

The native image library also requires CMake. On macOS, install the build tools
with `brew install cmake ninja` and confirm `cmake --version` works in the
terminal used to launch Flutter.

Run `flutter analyze` and `flutter test` for validation. Test on a physical iPhone
with camera permission enabled to check hand alignment in portrait and landscape,
mirroring, two hands, and background/resume behavior.


# To run on iOS device locally 
1. Check wirelessly connected devices by running `flutter devices`
2. Run `flutter run -d <device id from any of the devices returned from previous command>`

# To build a release to iOS device
1. Check wirelessly connected devices by running `flutter devices`
2. Run `flutter run --release -d <device id from any of the devices returned from previous command>`