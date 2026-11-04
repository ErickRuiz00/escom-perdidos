import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/escom.dart';
import '../../data/services/notification_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../../viewmodels/weather_viewmodel.dart';
import '../profile/profile_view.dart';
import '../reports/report_form_view.dart';
import '../widgets/common.dart';
import 'feed_view.dart';
import 'my_reports_view.dart';

/// Contenedor principal con navegación inferior (teléfono) o lateral (tablet).
///
/// Cualquier función clave queda a 3 toques o menos: pestaña → botón → acción.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Carga inicial tras el primer frame para que la UI aparezca de inmediato.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReportsViewModel>().load();
      context.read<WeatherViewModel>().load();
      if (context.read<AuthViewModel>().user?.notificationsEnabled ?? false) {
        context.read<NotificationService>().requestPermission();
      }
    });
  }

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Mis reportes'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  Future<void> _newReport() async {
    final type = await showModalBottomSheet<ReportType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Qué quieres reportar?',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final t in ReportType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    tileColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    leading: Icon(t.icon),
                    title: Text(t == ReportType.lost
                        ? 'Perdí algo'
                        : 'Encontré algo'),
                    subtitle: Text(t == ReportType.lost
                        ? 'Avisa a la comunidad qué buscas'
                        : 'Ayuda a que vuelva con su dueño'),
                    onTap: () => Navigator.pop(context, t),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportFormView(initialType: type),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayout;
    final pages = [
      FeedView(onNewReport: _newReport),
      MyReportsView(onNewReport: _newReport),
      const ProfileView(),
    ];
    final body = IndexedStack(index: _index, children: pages);
    final fab = _index == 2
        ? null
        : FloatingActionButton.extended(
            onPressed: _newReport,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Reportar'),
          );

    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.travel_explore_rounded, size: 32),
            ),
            destinations: [
              for (final (icon, selected, label) in _destinations)
                NavigationRailDestination(
                  icon: Icon(icon),
                  selectedIcon: Icon(selected),
                  label: Text(label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, selected, label) in _destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}
