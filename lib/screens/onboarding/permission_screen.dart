import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../providers/scanner_provider.dart';
import '../../providers/storage_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

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
    if (state == AppLifecycleState.resumed) {
      _checkAccess();
    }
  }

  Future<void> _checkAccess() async {
    final storageService = ref.read(storageServiceProvider);
    final granted = await storageService.hasAccess();
    if (!mounted) return;
    if (granted) {
      ref.read(scanControllerProvider.notifier).startScan();
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: AppRadius.borderLg,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Welcome to MediaRescue',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'MediaRescue requires storage access to discover lost media, index hidden files, and help you free up space.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Column(
                  children: const [
                    _BulletPoint(
                      icon: HugeIcons.strokeRoundedSearch01,
                      text: 'Scan storage for hidden files',
                    ),
                    SizedBox(height: AppSpacing.md),
                    _BulletPoint(
                      icon: HugeIcons.strokeRoundedHardDrive,
                      text: 'Identify & clean large files',
                    ),
                    SizedBox(height: AppSpacing.md),
                    _BulletPoint(
                      icon: HugeIcons.strokeRoundedSecurityCheck,
                      text: 'Everything stays strictly on your device',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Grant Storage Access',
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedSecurityCheck, color: Colors.white),
                onPressed: _requestAccess,
                isLoading: _isLoading,
                isFullWidth: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'You will be navigated to Android System Settings. Enable "Allow access to manage all files".',
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
  final List<List<dynamic>> icon;
  final String text;

  const _BulletPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, color: AppColors.primary, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}