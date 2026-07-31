import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  const SettingsScreen({super.key, required this.storage});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late var _profile = widget.storage.getProfile()!;

  Future<void> _toggleAutoReply(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn on Auto-reply?'),
          content: const Text(
            'In this mode, the app will pick and speak a reply for you '
            'automatically, without asking first. This is not recommended '
            '- automatic replies can be inaccurate or say something you '
            'didn\'t mean. You can turn this off again at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Turn on anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _profile.autoReplyEnabled = value);
    await widget.storage.saveProfile(_profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _PreferenceField(
            label: 'Preferred protein',
            initialValue: _profile.preferences['protein'] ?? '',
            onChanged: (v) => _profile.preferences['protein'] = v,
          ),
          _PreferenceField(
            label: 'Preferred drink',
            initialValue: _profile.preferences['drink'] ?? '',
            onChanged: (v) => _profile.preferences['drink'] = v,
          ),
          const SizedBox(height: 24),
          Text('Reply language', style: Theme.of(context).textTheme.titleLarge),
          RadioListTile<String>(
            title: const Text('English only'),
            value: 'english',
            groupValue: _profile.languagePreference,
            onChanged: (v) => setState(() => _profile.languagePreference = v!),
          ),
          RadioListTile<String>(
            title: const Text('Egyptian Arabic'),
            value: 'egyptianArabic',
            groupValue: _profile.languagePreference,
            onChanged: (v) => setState(() => _profile.languagePreference = v!),
          ),
          RadioListTile<String>(
            title: const Text('Mix of Arabic and English'),
            value: 'mixed',
            groupValue: _profile.languagePreference,
            onChanged: (v) => setState(() => _profile.languagePreference = v!),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Auto-reply mode'),
            subtitle: const Text(
              'Not recommended: the app replies for you automatically without confirmation.',
            ),
            value: _profile.autoReplyEnabled,
            onChanged: _toggleAutoReply,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await widget.storage.saveProfile(_profile);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _PreferenceField extends StatelessWidget {
  final String label;
  final String initialValue;
  final void Function(String) onChanged;

  const _PreferenceField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }
}
