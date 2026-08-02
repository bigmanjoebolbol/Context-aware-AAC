import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/app_strings.dart';
import '../models/user_profile.dart';
import 'contacts_management_screen.dart';

class PreferencesScreen extends StatefulWidget {
  final StorageService storage;
  const PreferencesScreen({super.key, required this.storage});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.getProfile()!;
  }

  Future<void> _save() async {
    await widget.storage.saveProfile(_profile);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang = _profile.uiLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('preferences', lang)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: AppStrings.get('cat_food', lang)),
          _PreferenceField(
            label: AppStrings.get('pref_protein', lang),
            initialValue: _profile.preferences['protein'] ?? '',
            onChanged: (v) => _profile.preferences['protein'] = v,
          ),
          _PreferenceField(
            label: AppStrings.get('pref_drink', lang),
            initialValue: _profile.preferences['drink'] ?? '',
            onChanged: (v) => _profile.preferences['drink'] = v,
          ),
          _PreferenceField(
            label: 'Coffee / Tea',
            initialValue: _profile.preferences['coffee_pref'] ?? '',
            onChanged: (v) => _profile.preferences['coffee_pref'] = v,
          ),
          _PreferenceField(
            label: 'Breakfast',
            initialValue: _profile.preferences['breakfast'] ?? '',
            onChanged: (v) => _profile.preferences['breakfast'] = v,
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: AppStrings.get('cat_lifestyle', lang)),
          _PreferenceField(
            label: 'Hobbies',
            initialValue: _profile.preferences['hobbies'] ?? '',
            onChanged: (v) => _profile.preferences['hobbies'] = v,
          ),
          _PreferenceField(
            label: 'Music',
            initialValue: _profile.preferences['music'] ?? '',
            onChanged: (v) => _profile.preferences['music'] = v,
          ),
          _PreferenceField(
            label: 'Movies',
            initialValue: _profile.preferences['movies'] ?? '',
            onChanged: (v) => _profile.preferences['movies'] = v,
          ),
          _PreferenceField(
            label: 'Sport',
            initialValue: _profile.preferences['sport'] ?? '',
            onChanged: (v) => _profile.preferences['sport'] = v,
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: AppStrings.get('cat_context', lang)),
          _PreferenceField(
            label: 'Family',
            initialValue: _profile.preferences['family'] ?? '',
            onChanged: (v) => _profile.preferences['family'] = v,
          ),
          _PreferenceField(
            label: 'Work / Study',
            initialValue: _profile.preferences['work_status'] ?? '',
            onChanged: (v) => _profile.preferences['work_status'] = v,
          ),
          _PreferenceField(
            label: 'Emergency Contact',
            initialValue: _profile.preferences['emergency_contact'] ?? '',
            onChanged: (v) => _profile.preferences['emergency_contact'] = v,
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Context & Safety'),
          SwitchListTile(
            title: const Text('Share location with AI'),
            subtitle: const Text('Allows AI to suggest replies based on where you are (e.g. at a shop)'),
            value: _profile.shareLocationWithAi,
            onChanged: (v) async {
              setState(() => _profile.shareLocationWithAi = v);
              await widget.storage.saveProfile(_profile);
            },
          ),
          ListTile(
            title: const Text('Manage Contacts'),
            subtitle: const Text('Add frequent people to personalize AI tone'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ContactsManagementScreen(storage: widget.storage)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            child: Text(AppStrings.get('save', lang)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).primaryColor,
            ),
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
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
