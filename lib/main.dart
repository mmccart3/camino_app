import 'package:flutter/material.dart';
import 'data/local_database.dart';
import 'data/camino_repository.dart';
import 'services/settings_service.dart';
import 'ui/screens.dart';

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
    title: 'Camino',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF245D4A)),
      scaffoldBackgroundColor: const Color(0xFFF7F6F0),
      appBarTheme: const AppBarTheme(centerTitle: false),
    ),
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return HomeScreen(repository: repository, settings: settings);
      },
    ),
  );
}
