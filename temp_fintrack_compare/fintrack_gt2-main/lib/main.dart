import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';

import 'theme/app_theme.dart';
import 'screens/auth_wrapper.dart';
import 'providers/firestore_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('es_GT', null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const ProviderScope(child: FinTrackGTApp()));
}

class FinTrackGTApp extends ConsumerWidget {
  const FinTrackGTApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(userPreferencesProvider);
    final themeMode = prefsAsync.when(
      data: (prefs) => prefs.toThemeMode(),
      loading: () => ThemeMode.system,
      error: (_, __) => ThemeMode.system,
    );
    return MaterialApp(
      title: 'Cifra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthWrapper(),
    );
  }
}
