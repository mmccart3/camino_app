import 'current_stage_map.dart';
import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../services/settings_service.dart';
import 'home_screen.dart';
import 'walking_day_screen.dart';
import 'stage_list_screen.dart';
import 'map_screen.dart';
import 'camino_plan_screen.dart';
import 'personal_library.dart';
import 'persistent_tabs.dart';

class AppShell extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  const AppShell({super.key, required this.repository, required this.settings});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final tabs = GlobalKey<PersistentTabsState>();
  bool open(Widget screen) {
    int? tab;
    if (screen is StageListScreen) tab = 1;
    if (screen is MapScreen) tab = 2;
    if (screen is CaminoPlansScreen || screen is PersonalLibraryScreen) tab = 3;
    if (screen is CaminoPlanScreen) tab = 3;
    if (tab == null) return false;
    if (screen is StageListScreen) {
      tabs.currentState!.select(tab);
      return true;
    }
    final name = screen is MapScreen
        ? 'map/${screen.stage.id}'
        : screen is CaminoPlanScreen
        ? 'plan/${screen.plan.id}'
        : screen is PersonalLibraryScreen
        ? 'library'
        : 'plans';
    tabs.currentState!.show(tab, name, screen);
    return true;
  }

  Widget root(int index) => switch (index) {
    0 => HomeScreen(repository: widget.repository, settings: widget.settings),
    1 => StageListScreen(
      repository: widget.repository,
      settings: widget.settings,
    ),
    2 => CurrentStageMap(
      repository: widget.repository,
      settings: widget.settings,
    ),
    _ => Scaffold(
      appBar: AppBar(title: const Text('My Camino'), centerTitle: true),
      body: SafeArea(
        child: Builder(
          builder: (context) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_note),
                  title: const Text('My walking day'),
                  subtitle: const Text('Plan a day, stops and breaks'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WalkingDayScreen(
                        repository: widget.repository,
                        settings: widget.settings,
                      ),
                    ),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.route),
                  title: const Text('My itinerary'),
                  subtitle: const Text('Walking days and overnight stays'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: 'plans'),
                      builder: (_) => CaminoPlansScreen(
                        repository: widget.repository,
                        settings: widget.settings,
                      ),
                    ),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.book_outlined),
                  title: const Text('Favourites & diary'),
                  subtitle: const Text('Saved places, notes, photos and PDFs'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: 'library'),
                      builder: (_) =>
                          PersonalLibraryScreen(repository: widget.repository),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  };
  @override
  Widget build(BuildContext context) => PersistentTabs(
    key: tabs,
    root: (context, index) => root(index),
    open: open,
  );
}
