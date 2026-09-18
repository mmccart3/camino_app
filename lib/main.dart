import 'package:flutter/material.dart';
import 'data/local_database.dart';
import 'data/camino_repository.dart';
import 'services/settings_service.dart';
import 'ui/screens.dart';
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
    await Future.wait<void>([
      () async {
        await local.database;
        await settings.load();
      }(),
      Future<void>.delayed(const Duration(seconds: 2)),
    ]);
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
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SelectableText(
                    'Could not prepare the local database.\n${snapshot.error}',
                  ),
                  FilledButton(
                    onPressed: () => setState(() {
                      initialization = initialize();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        return HomeScreen(repository: repository, settings: settings);
      },
    ),
  );
}
