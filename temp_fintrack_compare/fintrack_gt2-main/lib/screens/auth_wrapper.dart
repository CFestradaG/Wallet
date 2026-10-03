import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/seed_service.dart';
import 'login_screen.dart';
import 'home_navigator.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // Primer login → sembrar datos si no existen
          SeedService().seedIfNeeded(user).catchError((e) {
            debugPrint('Seed error: $e');
          });
          return const HomeNavigator();
        } else {
          return const LoginScreen();
        }
      },
      loading: () => Scaffold(
        backgroundColor: AppTheme.pageBackground(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Cifra',
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                'Error de autenticación',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
