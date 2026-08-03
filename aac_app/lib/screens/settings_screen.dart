import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/app_strings.dart';
import '../services/stt_service.dart';
import '../services/local_ai_manager.dart';
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
          RadioGroup<String>(
            groupValue: _profile.uiLanguage,
            onChanged: (v) async {
              setState(() => _profile.uiLanguage = v!);
              await widget.storage.saveProfile(_profile);
            },
            child: const Column(
              children: [
                RadioListTile(title: Text('English'), value: 'en'),
                RadioListTile(title: Text('العربية'), value: 'ar'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Speech Recognition Language', style: Theme.of(context).textTheme.titleLarge),
          RadioGroup<String>(
            groupValue: _profile.languagePreference,
            onChanged: (v) async {
              setState(() => _profile.languagePreference = v!);
              await widget.storage.saveProfile(_profile);
            },
            child: const Column(
              children: [
                RadioListTile(title: Text('English'), value: 'english'),
                RadioListTile(title: Text('Arabic / العربية'), value: 'mixed'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(AppStrings.get('theme_mode', lang), style: Theme.of(context).textTheme.titleLarge),
          RadioGroup<String>(
            groupValue: _profile.themeMode,
            onChanged: (v) async {
              setState(() => _profile.themeMode = v!);
              await widget.storage.saveProfile(_profile);
            },
            child: Column(
              children: [
                RadioListTile(title: Text(AppStrings.get('theme_light', lang)), value: 'light'),
                RadioListTile(title: Text(AppStrings.get('theme_dark', lang)), value: 'dark'),
                RadioListTile(title: Text(AppStrings.get('theme_hc', lang)), value: 'highContrast'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('TTS Voice', style: Theme.of(context).textTheme.titleLarge),
          RadioGroup<String>(
            groupValue: _profile.preferences['tts_gender'] ?? 'female',
            onChanged: (v) async {
              setState(() => _profile.preferences['tts_gender'] = v!);
              await widget.storage.saveProfile(_profile);
            },
            child: const Column(
              children: [
                RadioListTile(title: Text('Female'), value: 'female'),
                RadioListTile(title: Text('Male'), value: 'male'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('AI Mode', style: Theme.of(context).textTheme.titleLarge),
          RadioGroup<String>(
            groupValue: _profile.aiMode.isEmpty ? 'gemini' : _profile.aiMode,
            onChanged: (v) async {
              if (v == 'local_on_device') {
                final manager = LocalAiManager();
                if (!await manager.checkHardwareSpecs()) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device does not meet hardware requirements for local AI.')),
                    );
                  }
                  return;
                }
                if (!await manager.isModelDownloaded()) {
                  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Downloading Local AI'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueListenableBuilder<double>(
                              valueListenable: progressNotifier,
                              builder: (context, progress, child) {
                                return Column(
                                  children: [
                                    LinearProgressIndicator(value: progress > 0 ? progress : null),
                                    const SizedBox(height: 16),
                                    Text(progress > 0 
                                      ? 'Downloading... ${(progress * 100).toStringAsFixed(1)}%'
                                      : 'Starting download (~1.1GB)...'),
                                  ],
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  try {
                    await manager.downloadModel(onProgress: (p) {
                      progressNotifier.value = p;
                    });
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to download local model.')),
                      );
                    }
                    return;
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              }
              setState(() => _profile.aiMode = v!);
              await widget.storage.saveProfile(_profile);
            },
            child: const Column(
              children: [
                RadioListTile(
                  title: Text('☁️  Cloud AI (Groq)'),
                  subtitle: Text('Requires internet. Works on any device.'),
                  value: 'gemini',
                ),

                RadioListTile(
                  title: Text('📱  On-Device Local AI (Qwen2.5-1.5b)'),
                  subtitle: Text('Truly offline. Requires good hardware & downloads ~1.1GB.'),
                  value: 'local_on_device',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Custom Backend URL (Advanced)', style: Theme.of(context).textTheme.titleLarge),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'e.g. http://192.168.0.101:8080/suggest',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(
                text: _profile.preferences['backend_url'] ?? '',
              ),
              onChanged: (v) {
                _profile.preferences['backend_url'] = v.trim();
              },
            ),
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
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
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
        color: Colors.grey.withValues(alpha: 0.2),
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

