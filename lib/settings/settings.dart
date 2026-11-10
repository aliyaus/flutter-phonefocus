import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  const Settings({
    super.key,
    required this.onDarkModeChanged,
    required this.selectedSound,
    required this.onSoundChanged,
    required this.showLivePreview,
    required this.onLivePreviewChanged,
    required this.handDetection,
    required this.onHandDetectionChanged,
    required this.pickupDetection,
    required this.onPickupDetectionChanged,
    required this.eyeDetection,
    required this.onEyeDetectionChanged,
  });

  final ValueChanged<bool> onDarkModeChanged;
  final String selectedSound;
  final ValueChanged<String> onSoundChanged;
  final bool showLivePreview;
  final ValueChanged<bool> onLivePreviewChanged;
  final bool handDetection;
  final ValueChanged<bool> onHandDetectionChanged;
  final bool pickupDetection;
  final ValueChanged<bool> onPickupDetectionChanged;
  final bool eyeDetection;
  final ValueChanged<bool> onEyeDetectionChanged;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late bool _handDetection;
  late bool _pickupDetection;
  late bool _eyeDetection;
  late String _selectedSound;
  late bool _showLivePreview;

  @override
  void initState() {
    super.initState();
    _selectedSound = widget.selectedSound;
    _showLivePreview = widget.showLivePreview;
    _handDetection = widget.handDetection;
    _pickupDetection = widget.pickupDetection;
    _eyeDetection = widget.eyeDetection;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Center(
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: widget.onDarkModeChanged,
              secondary: const Icon(Icons.dark_mode),
            ),
            SwitchListTile(
              title: const Text('Live camera preview'),
              value: _showLivePreview,
              onChanged: (bool value) {
                setState(() => _showLivePreview = value);
                widget.onLivePreviewChanged(value);
              },
              secondary: const Icon(Icons.videocam),
            ),
            SwitchListTile(
              title: const Text('All detections'),
              value: _handDetection && _pickupDetection && _eyeDetection,
              onChanged: (bool value) {
                setState(() {
                  _handDetection = value;
                  _pickupDetection = value;
                  _eyeDetection = value;
                });
                widget.onHandDetectionChanged(value);
                widget.onPickupDetectionChanged(value);
                widget.onEyeDetectionChanged(value);
              },
              secondary: const Icon(Icons.lightbulb_outline),
            ),
            SwitchListTile(
              title: const Text('Hand detection'),
              value: _handDetection,
              onChanged: (bool value) {
                setState(() {
                  _handDetection = value;
                });
                widget.onHandDetectionChanged(value);
              },
              secondary: const Icon(Icons.handshake),
            ),
            SwitchListTile(
              title: const Text('Pick up detection'),
              value: _pickupDetection,
              onChanged: (bool value) {
                setState(() {
                  _pickupDetection = value;
                });
                widget.onPickupDetectionChanged(value);
              },
              secondary: const Icon(Icons.line_axis_rounded),
            ),
            SwitchListTile(
              title: const Text('Eye detection'),
              value: _eyeDetection,
              onChanged: (bool value) {
                setState(() => _eyeDetection = value);
                widget.onEyeDetectionChanged(value);
              },
              secondary: const Icon(Icons.visibility),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Sound'),
              trailing: DropdownButton<String>(
                value: _selectedSound,
                items: const [
                  DropdownMenuItem(
                    value: 'fahhhsound.mp3',
                    child: Text('Fahhh'),
                  ),
                  DropdownMenuItem(
                    value: 'getouttt.mp3',
                    child: Text('Get Out'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _selectedSound = value;
                  });
                  widget.onSoundChanged(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
