import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/storage_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../services/notification_service.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns from the system settings page, re-check permission.
    if (state == AppLifecycleState.resumed) {
      _checkAccess();
    }
  }

  Future<void> _checkAccess() async {
    final storageService = ref.read(storageServiceProvider);
    final granted = await storageService.hasAccess();
    if (!mounted) return;
    if (granted) {
      // Start the full-storage scan and navigate home.
      ref.read(scanControllerProvider.notifier).startScan();
      // After onboarding completes, ask for notification permission once
      // (Android only shows the dialog while the OS status is undecided).
      NotificationService.requestPermissionIfNeeded();
      context.go('/home');
    }
  }

  Future<void> _requestAccess() async {
    setState(() => _isLoading = true);
    final storageService = ref.read(storageServiceProvider);
    await storageService.requestAccess();
    if (!mounted) return;
    setState(() => _isLoading = false);
    // The user will return from the system settings page.
    // didChangeAppLifecycleState → _checkAccess handles the rest.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.folder_special,
                size: 100,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to MediaRescue',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'MediaRescue needs full access to your device storage to find '
                'hidden media files, analyze storage usage, and help you manage '
                'large files.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BulletPoint(
                        icon: Icons.visibility,
                        text: 'Scan every folder on your device',
                      ),
                      const SizedBox(height: 8),
                      _BulletPoint(
                        icon: Icons.search,
                        text: 'Find hidden media and large files',
                      ),
                      const SizedBox(height: 8),
                      _BulletPoint(
                        icon: Icons.lock_outline,
                        text: 'Everything stays on your device — nothing is uploaded',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton.icon(
                  onPressed: _requestAccess,
                  icon: const Icon(Icons.security),
                  label: const Text('Grant Full Storage Access'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'You will be taken to Android settings. Enable '
                '"Allow access to manage all files" and return to MediaRescue.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BulletPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}