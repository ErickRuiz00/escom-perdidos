import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/splash/presentation/animated_circuit_logo.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notifications_viewmodel.dart';
import '../../viewmodels/tutorial_viewmodel.dart';
import '../../core/errors/app_exception.dart';
import '../help/section_tutorial_overlay.dart';
import '../profile/profile_view.dart';
import '../reports/report_form_view.dart';
import '../reports/report_detail_view.dart';
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  final _exploreSearch = TextEditingController();
  final _shellKey = GlobalKey();
  final _navigationKey = GlobalKey();
  final _railLabels = List.generate(5, (_) => GlobalKey());
  Rect? _tutorialTarget;
  bool _targetScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ReportsViewModel>().bindUser(
          context.read<AuthViewModel>().user?.id,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exploreSearch.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<NotificationsViewModel>().load();
    }
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

  void _measureTutorial(bool wide, TutorialViewModel tutorial) {
    if (_targetScheduled) return;
    _targetScheduled = true;
    final step = tutorial.step, revision = tutorial.revision;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _targetScheduled = false;
      if (!mounted ||
          !tutorial.active ||
          tutorial.step != step ||
          tutorial.revision != revision) {
        return;
      }
      final labelContext = _railLabels[step].currentContext;
      if (wide && labelContext != null) {
        await Scrollable.ensureVisible(labelContext, alignment: 0.5);
      }
      if (!mounted ||
          !tutorial.active ||
          tutorial.step != step ||
          tutorial.revision != revision) {
        return;
      }
      final shell = _shellKey.currentContext?.findRenderObject();
      final navigation = _navigationKey.currentContext?.findRenderObject();
      if (shell is! RenderBox ||
          navigation is! RenderBox ||
          !shell.hasSize ||
          !navigation.hasSize) {
        return;
      }
      final origin = shell.globalToLocal(navigation.localToGlobal(Offset.zero));
      Rect target;
      if (wide) {
        final label = labelContext?.findRenderObject();
        if (label is! RenderBox || !label.hasSize) return;
        final labelOrigin = shell.globalToLocal(
          label.localToGlobal(Offset.zero),
        );
        target = Rect.fromLTRB(
          origin.dx + 5,
          labelOrigin.dy - 42,
          origin.dx + navigation.size.width - 5,
          labelOrigin.dy + label.size.height + 8,
        );
      } else {
        final slot = navigation.size.width / 5;
        target = Rect.fromLTWH(
          origin.dx + slot * step + 3,
          origin.dy + 4,
          slot - 6,
          navigation.size.height - MediaQuery.paddingOf(context).bottom - 8,
        );
      }
      target = target.intersect((Offset.zero & shell.size).deflate(2));
      if (target != _tutorialTarget) setState(() => _tutorialTarget = target);
    });
  }

  Future<void> _finishTutorial() async {
    final tutorial = context.read<TutorialViewModel>();
    if (!tutorial.active) return;
    final notifications = context.read<NotificationsViewModel>();
    final session = notifications.sessionRevision;
    setState(() {
      _index = tutorial.step;
      _tutorialTarget = null;
    });
    tutorial.stop();
    try {
      notifications.assertSession(session);
      await notifications.completeTutorial();
    } catch (e) {
      if (mounted && notifications.sessionRevision == session) {
        showSnack(
          context,
          'Cerraste la guía. ${userMessageFor(e)}',
          error: true,
        );
      }
    }
  }

  void _nextTutorial() {
    final tutorial = context.read<TutorialViewModel>();
    if (tutorial.step == 4) {
      _finishTutorial();
    } else {
      tutorial.goTo(tutorial.step + 1);
    }
  }

  void _search(String query) {
    _exploreSearch.text = query;
    _select(1);
  }

  Future<void> _newReport() async {
    final id = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ReportFormView()));
    if (id != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReportDetailView(reportId: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayout;
    final tutorial = context.watch<TutorialViewModel>();
    final index = tutorial.active ? tutorial.step : _index;
    if (tutorial.active) _measureTutorial(wide, tutorial);
    final pages = <Widget>[
      FeedView(onNewReport: _newReport, onSearch: _search),
      ExploreView(searchController: _exploreSearch),
      PublishView(onContinue: _newReport),
      const ChatsView(),
      ProfileView(onNewReport: _newReport),
    ];
    final body = IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < pages.length; i++)
          HeroMode(
            enabled: i == index,
            child: TickerMode(enabled: i == index, child: pages[i]),
          ),
      ],
    );
    return PopScope(
      canPop: !tutorial.active && _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (tutorial.active) {
            _finishTutorial();
          } else {
            _select(0);
          }
        }
      },
      child: Stack(
        key: _shellKey,
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: tutorial.active,
            child: AbsorbPointer(
              absorbing: tutorial.active,
              child: Scaffold(
                body: wide
                    ? SafeArea(
                        child: Row(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: IntrinsicHeight(
                                        child: NavigationRail(
                                          key: _navigationKey,
                                          selectedIndex: index,
                                          onDestinationSelected: _select,
                                          labelType:
                                              NavigationRailLabelType.all,
                                          leading: const AnimatedCircuitLogo(
                                            progress: AlwaysStoppedAnimation(1),
                                            size: 64,
                                          ),
                                          destinations: [
                                            for (
                                              var i = 0;
                                              i < _destinations.length;
                                              i++
                                            )
                                              NavigationRailDestination(
                                                icon: Icon(_destinations[i].$1),
                                                selectedIcon: Icon(
                                                  _destinations[i].$2,
                                                ),
                                                label: Text(
                                                  _destinations[i].$3,
                                                  key: _railLabels[i],
                                                ),
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
                        key: _navigationKey,
                        selectedIndex: index,
                        onDestinationSelected: _select,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
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
            ),
          ),
          if (tutorial.active)
            Positioned.fill(
              child: SectionTutorialOverlay(
                step: tutorial.step,
                target: _tutorialTarget,
                wide: wide,
                onNext: _nextTutorial,
                onPrevious: () => tutorial.goTo(tutorial.step - 1),
                onSkip: _finishTutorial,
              ),
            ),
        ],
      ),
    );
  }
}
