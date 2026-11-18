import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/splash/presentation/animated_circuit_logo.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../profile/profile_view.dart';
import '../reports/report_form_view.dart';
import '../widgets/common.dart';
import 'community_views.dart';
import 'explore_view.dart';
import 'feed_view.dart';

/// Conserva el estado de las cinco secciones, incluidos scroll y filtros.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _exploreSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReportsViewModel>().load();
    });
  }

  @override
  void dispose() {
    _exploreSearch.dispose();
    super.dispose();
  }

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.search_rounded, Icons.manage_search_rounded, 'Explorar'),
    (Icons.add_box_outlined, Icons.add_box_rounded, 'Publicar'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chats'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  void _select(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = index);
  }

  void _search(String query) {
    _exploreSearch.text = query;
    _select(1);
  }

  void _newReport() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ReportFormView()));

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayout;
    final pages = <Widget>[
      FeedView(onNewReport: _newReport, onSearch: _search),
      ExploreView(searchController: _exploreSearch),
      PublishView(onContinue: _newReport),
      const ChatsView(),
      ProfileView(onNewReport: _newReport),
    ];
    final body = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < pages.length; i++)
          TickerMode(enabled: i == _index, child: pages[i]),
      ],
    );
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: wide
            ? SafeArea(
                child: Row(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              selectedIndex: _index,
                              onDestinationSelected: _select,
                              labelType: NavigationRailLabelType.all,
                              leading: const AnimatedCircuitLogo(
                                progress: AlwaysStoppedAnimation(1),
                                size: 64,
                              ),
                              destinations: [
                                for (final (icon, selected, label)
                                    in _destinations)
                                  NavigationRailDestination(
                                    icon: Icon(icon),
                                    selectedIcon: Icon(selected),
                                    label: Text(label),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                ),
              )
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final (icon, selected, label) in _destinations)
                    NavigationDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: label,
                    ),
                ],
              ),
      ),
    );
  }
}
