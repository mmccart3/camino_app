import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'data/local_database.dart';
import 'data/camino_repository.dart';
import 'services/settings_service.dart';
import 'ui/app_shell.dart';
import 'ui/app_title.dart';
import 'ui/app_theme.dart';
import 'ui/splash_screen.dart';
import 'ui/walking_alerts.dart';
import 'ui/app_viewport.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CaminoApp());
}

class CaminoApp extends StatefulWidget {
  const CaminoApp({super.key});
  @override
  State<CaminoApp> createState() => _CaminoAppState();
}

class _CaminoAppState extends State<CaminoApp> {
  final local = LocalDatabase();
  final settings = SettingsService();
  late final repository = CaminoRepository(local);
  late Future<void> initialization = initialize();
  Future<void> initialize() async {
    await local.database;
    await settings.load();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appTitle,
    builder: (context, child) => AppViewport(
      child: Column(
        children: [
          Expanded(child: child ?? const SizedBox.shrink()),
          const WalkingSessionBanner(),
        ],
      ),
    ),
    debugShowCheckedModeBanner: false,
    theme: buildCaminoTheme(),
    home: FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Camino setup')),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.storage_rounded, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Your guide could not be opened',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Text(
                      'Please try again. Your saved plans and diary have not been reset.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        initialization = initialize();
                      }),
                      child: const Text('Retry'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy diagnostic details'),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: 'Camino database setup: ${snapshot.error}',
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Diagnostic details copied'),
                            ),
                          );
                        }
                      },
                    ),
                    ExpansionTile(
                      title: const Text('Technical details'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText('${snapshot.error}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        return AppShell(repository: repository, settings: settings);
      },
    ),
  );
}
