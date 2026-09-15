import 'package:flutter/material.dart';
import 'app_title.dart';
import 'app_logo.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the installed package, including Flutter build-name/number overrides.
class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({super.key});
  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  late final Future<PackageInfo> info = PackageInfo.fromPlatform().timeout(
    const Duration(seconds: 3),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: info,
    builder: (context, snapshot) {
      final package = snapshot.data;
      return Text(
        package == null
            ? (snapshot.hasError
                  ? 'Version information unavailable'
                  : 'Loading version…')
            : 'Version ${package.version} · Build ${package.buildNumber}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    },
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 220),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: caminoBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const AppTitle(),
              ),
              const SizedBox(height: 8),
              const Text('One stage at a time.', textAlign: TextAlign.center),
              const SizedBox(height: 32),
              const AppVersionLabel(),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 12),
              const Text(
                'Preparing your offline guide…',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
