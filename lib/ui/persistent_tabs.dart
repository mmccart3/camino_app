import 'package:flutter/material.dart';
import 'feature_navigation.dart';

/// Four independent, lazily-created route stacks. Tab changes do not pop routes.
class PersistentTabs extends StatefulWidget {
  final Widget Function(BuildContext, int) root;
  final bool Function(Widget) open;
  const PersistentTabs({super.key, required this.root, required this.open});
  @override
  State<PersistentTabs> createState() => PersistentTabsState();
}

class PersistentTabsState extends State<PersistentTabs> {
  int selected = 0;
  final visited = <int>{0};
  final keys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  bool canGoBack = false;
  final stacks = List.generate(4, (_) => <Route<dynamic>>[]);
  late final observers = List.generate(
    4,
    (i) => _StackObserver(refreshBack, stacks[i]),
  );
  void show(int index, String name, Widget screen) {
    select(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = keys[index].currentState!;
      final existing = stacks[index]
          .where((r) => r.settings.name == name)
          .firstOrNull;
      if (existing != null) {
        navigator.popUntil((r) => identical(r, existing));
      } else {
        navigator.push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: name),
            builder: (_) => screen,
          ),
        );
      }
    });
  }

  void refreshBack() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(
          () => canGoBack = keys[selected].currentState?.canPop() ?? false,
        );
      }
    });
  }

  void select(int index) {
    setState(() {
      selected = index;
      visited.add(index);
    });
    refreshBack();
  }

  @override
  Widget build(BuildContext context) => FeatureNavigation(
    open: widget.open,
    selected: selected,
    child: PopScope(
      canPop: selected == 0 && !canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final nav = keys[selected].currentState;
        if (nav?.canPop() ?? false) {
          nav!.pop();
        } else if (selected != 0) {
          select(0);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: selected,
          children: [
            for (var i = 0; i < 4; i++)
              if (!visited.contains(i))
                const SizedBox.shrink()
              else
                TickerMode(
                  enabled: i == selected,
                  child: Navigator(
                    key: keys[i],
                    observers: [observers[i]],
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (context) => widget.root(context, i),
                    ),
                  ),
                ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (index) {
            if (index == selected) {
              keys[index].currentState?.popUntil((r) => r.isFirst);
            } else {
              select(index);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'My Camino',
            ),
          ],
        ),
      ),
    ),
  );
}

class _StackObserver extends NavigatorObserver {
  final VoidCallback changed;
  final List<Route<dynamic>> routes;
  _StackObserver(this.changed, this.routes);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        routes.removeAt(index);
      } else {
        routes[index] = newRoute;
      }
    }
    changed();
  }
}
