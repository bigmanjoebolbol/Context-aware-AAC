import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/conversation_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  runApp(ContextAwareAacApp(storage: storage));
}

class ContextAwareAacApp extends StatelessWidget {
  final StorageService storage;
  const ContextAwareAacApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: storage,
      builder: (context, child) {
        final profile = storage.getProfile();
        final startScreen = (profile != null && profile.onboardingComplete)
            ? ConversationScreen(storage: storage)
            : OnboardingScreen(storage: storage);

        final theme = switch (profile?.themeMode) {
          'dark' => AppTheme.dark(),
          'highContrast' => AppTheme.highContrast(),
          _ => AppTheme.light(),
        };

        return MaterialApp(
          title: 'Context-Aware AAC',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: startScreen,
        );
      },
    );
  }
}
