import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  const Settings({
    super.key,
    required this.onDarkModeChanged,
    required this.selectedSound,
    required this.onSoundChanged,
  });

  final ValueChanged<bool> onDarkModeChanged;
  final String selectedSound;
  final ValueChanged<String> onSoundChanged;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _handDetection = false;
  bool _pickupDetection = false;
  late String _selectedSound;

  @override
  void initState() {
    super.initState();
    _selectedSound = widget.selectedSound;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Center(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: widget.onDarkModeChanged,
              secondary: const Icon(Icons.dark_mode),
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
            SwitchListTile(
              title: const Text('All detections'),
              value: _handDetection && _pickupDetection,
              onChanged: (bool value) {
                setState(() {
                  _handDetection = value;
                  _pickupDetection = value;
                });
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
              },
              secondary: const Icon(Icons.line_axis_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
