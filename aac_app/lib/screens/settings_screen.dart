import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/app_strings.dart';
import '../services/llm_fallback_service.dart';
import '../services/stt_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'preferences_screen.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  const SettingsScreen({super.key, required this.storage});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _profile = widget.storage.getProfile()!;
  final SttService _stt = SttService();
  bool _testingMic = false;
  bool _manuallyStopped = false;
  double _testVolume = 0.0;

  @override
  void initState() {
    super.initState();
    _checkMicStatus();
  }

  Future<void> _checkMicStatus() async {
    // Just initialize to see if it's available/detected by the OS
    await _stt.init();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_testingMic) _stt.stopListening();
    super.dispose();
  }

  Future<void> _toggleMicTest() async {
    if (_testingMic) {
      _manuallyStopped = true;
      await _stt.stopListening();
      setState(() {
        _testingMic = false;
        _testVolume = 0.0;
      });
      return;
    }

    _manuallyStopped = false;
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (!mounted) return;
      final lang = _profile.uiLanguage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('mic_permission_denied', lang)),
          action: SnackBarAction(
            label: AppStrings.get('open_settings', lang),
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    if (!_stt.isAvailable) {
      final ok = await _stt.init();
      if (!ok) return;
    }

    setState(() => _testingMic = true);
    _startListeningInternal();
  }

  Future<void> _startListeningInternal() async {
    if (!_testingMic || _manuallyStopped) return;
    await _stt.startListening(
      localeId: _profile.languagePreference == 'english' ? 'en-US' : 'ar-EG',
      onResult: (_, isFinal) {
        if (isFinal && _testingMic && !_manuallyStopped) {
          Future.delayed(const Duration(milliseconds: 100), () => _startListeningInternal());
        }
      },
      onError: (_) {
        if (_testingMic && !_manuallyStopped) {
          Future.delayed(const Duration(milliseconds: 300), () => _startListeningInternal());
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _testVolume = level);
      },
    );
  }

  Future<void> _toggleAutoReply(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppStrings.get('auto_reply_mode', _profile.uiLanguage)),
          content: Text(AppStrings.get('auto_reply_sub', _profile.uiLanguage)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.get('cancel', _profile.uiLanguage)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(AppStrings.get('say_it', _profile.uiLanguage)),
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
    final lang = _profile.uiLanguage;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('settings', lang))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(AppStrings.get('preferences', lang)),
            subtitle: const Text('Manage your food, hobbies, and personal context'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PreferencesScreen(storage: widget.storage),
                ),
              );
              setState(() {});
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          Text(AppStrings.get('ui_lang', lang), style: Theme.of(context).textTheme.titleLarge),
          RadioListTile<String>(
            title: const Text('English'),
            value: 'en',
            groupValue: _profile.uiLanguage,
            onChanged: (v) async {
              setState(() => _profile.uiLanguage = v!);
              await widget.storage.saveProfile(_profile);
            },
          ),
          RadioListTile<String>(
            title: const Text('العربية'),
            value: 'ar',
            groupValue: _profile.uiLanguage,
            onChanged: (v) async {
              setState(() => _profile.uiLanguage = v!);
              await widget.storage.saveProfile(_profile);
            },
          ),
          const SizedBox(height: 24),
          Text('Speech Recognition Language', style: Theme.of(context).textTheme.titleLarge),
          RadioListTile<String>(
            title: const Text('English'),
            value: 'english',
            groupValue: _profile.languagePreference,
            onChanged: (v) async {
              setState(() => _profile.languagePreference = v!);
              await widget.storage.saveProfile(_profile);
            },
          ),
          RadioListTile<String>(
            title: const Text('Arabic / العربية'),
            value: 'mixed',
            groupValue: _profile.languagePreference,
            onChanged: (v) async {
              setState(() => _profile.languagePreference = v!);
              await widget.storage.saveProfile(_profile);
            },
          ),
          const SizedBox(height: 24),
          Text(AppStrings.get('select_ai', lang), style: Theme.of(context).textTheme.titleLarge),
          _AiProviderPicker(
            storage: widget.storage,
            profile: _profile,
            onChanged: (id) async {
              setState(() => _profile.selectedAiProvider = id);
              await widget.storage.saveProfile(_profile);
            },
          ),
          const SizedBox(height: 24),
          Text(AppStrings.get('theme_mode', lang), style: Theme.of(context).textTheme.titleLarge),
          RadioListTile<String>(
            title: Text(AppStrings.get('theme_light', lang)),
            value: 'light',
            groupValue: _profile.themeMode,
            onChanged: (v) async {
              setState(() => _profile.themeMode = v!);
              await widget.storage.saveProfile(_profile);
            },
          ),
          RadioListTile<String>(
            title: Text(AppStrings.get('theme_dark', lang)),
            value: 'dark',
            groupValue: _profile.themeMode,
            onChanged: (v) async {
              setState(() => _profile.themeMode = v!);
              await widget.storage.saveProfile(_profile);
            },
          ),
          RadioListTile<String>(
            title: Text(AppStrings.get('theme_hc', lang)),
            value: 'highContrast',
            groupValue: _profile.themeMode,
            onChanged: (v) async {
              setState(() => _profile.themeMode = v!);
              await widget.storage.saveProfile(_profile);
            },
          ),
          const SizedBox(height: 24),
          Text(AppStrings.get('audio_mic', lang), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            title: Text(AppStrings.get('mic_status', lang)),
            subtitle: Text(
              _stt.isAvailable ? AppStrings.get('mic_ready', lang) : AppStrings.get('mic_not_ready', lang),
              style: TextStyle(
                color: _stt.isAvailable ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: ElevatedButton(
              onPressed: _toggleMicTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: _testingMic ? Colors.red : null,
                minimumSize: const Size(120, 40),
              ),
              child: Text(AppStrings.get(_testingMic ? 'stop_test' : 'test_mic', lang)),
            ),
          ),
          if (_testingMic)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.get('volume_level', lang)),
                  const SizedBox(height: 8),
                  _VolumeBar(level: _testVolume),
                ],
              ),
            ),
          ListTile(
            title: Text(AppStrings.get('open_settings', lang)),
            subtitle: const Text('Configure permissions manually in system settings'),
            trailing: const Icon(Icons.settings_applications),
            onTap: () => openAppSettings(),
          ),
          const SizedBox(height: 24),
          Text('Response settings', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            title: Text(AppStrings.get('auto_reply_mode', lang)),
            subtitle: Text(AppStrings.get('auto_reply_sub', lang)),
            value: _profile.autoReplyEnabled,
            onChanged: _toggleAutoReply,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await widget.storage.saveProfile(_profile);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: Text(AppStrings.get('save', lang)),
          ),
        ],
      ),
    );
  }
}

class _VolumeBar extends StatelessWidget {
  final double level;
  const _VolumeBar({required this.level});

  @override
  Widget build(BuildContext context) {
    // Use standardized normalization
    final normalized = SttService.normalizeLevel(level);

    return Container(
      height: 12,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: normalized,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _AiProviderPicker extends StatefulWidget {
  final StorageService storage;
  final UserProfile profile;
  final void Function(String) onChanged;

  const _AiProviderPicker({
    required this.storage,
    required this.profile,
    required this.onChanged,
  });

  @override
  State<_AiProviderPicker> createState() => _AiProviderPickerState();
}

class _AiProviderPickerState extends State<_AiProviderPicker> {
  List<AiProvider> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final service = LlmFallbackService(
        backendEndpoint: LlmFallbackService.defaultBackendUrl,
      );
      final result = await service.getProviders();
      if (mounted) {
        setState(() {
          _providers = result?.providers ?? [];
        });
      }
    } catch (_) {
      // Fail silently, list stays empty
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    if (_providers.isEmpty) return const Text('Using system default AI.');

    return Column(
      children: _providers.map((p) {
        return RadioListTile<String>(
          title: Text(p.label),
          subtitle: Text(p.model),
          value: p.id,
          groupValue: widget.profile.selectedAiProvider,
          onChanged: (v) => widget.onChanged(v!),
        );
      }).toList(),
    );
  }
}
