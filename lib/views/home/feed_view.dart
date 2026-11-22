import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/splash/presentation/animated_circuit_logo.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../../viewmodels/notifications_viewmodel.dart';
import '../notifications/notifications_view.dart';
import '../help/tutorial_view.dart';
import '../widgets/common.dart';
import 'community_views.dart';

class FeedView extends StatefulWidget {
  const FeedView({
    super.key,
    required this.onNewReport,
    required this.onSearch,
  });
  final VoidCallback onNewReport;
  final ValueChanged<String> onSearch;
  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<AuthViewModel, String>(
      (a) => a.user?.name ?? '',
    );
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        titleSpacing: 12,
        title: Row(
          children: [
            const AnimatedCircuitLogo(
              progress: AlwaysStoppedAnimation(1),
              size: 52,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encuéntralo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Text(
                    'ESCOM / IPN',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.secondary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton.outlined(
            tooltip: 'Centro de notificaciones',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsView(),
              ),
            ),
            icon: Badge(
              isLabelVisible:
                  context.watch<NotificationsViewModel>().unreadCount > 0,
              label: Text(
                '${context.watch<NotificationsViewModel>().unreadCount}',
              ),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const PageStorageKey('home-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            ConstrainedContent(
              maxWidth: 880,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TutorialInvitation(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: reducedMotion ? 1 : 0, end: 1),
                    duration: reducedMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primaryContainer,
                            colors.tertiaryContainer,
                          ],
                        ),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -22,
                            bottom: -38,
                            child: ExcludeSemantics(
                              child: Opacity(
                                opacity: 0.13,
                                child: const AnimatedCircuitLogo(
                                  progress: AlwaysStoppedAnimation(1),
                                  size: 215,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CONECTAMOS A LA COMUNIDAD',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onPrimaryContainer,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  firstName.isEmpty
                                      ? 'Hola, te damos la bienvenida'
                                      : 'Hola, $firstName',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        color: colors.onPrimaryContainer,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.8,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Cada hallazgo es una\noportunidad de reencontrar.',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.school_outlined,
                                      size: 18,
                                      color: colors.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Hecho para nuestra ESCOM',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onPrimaryContainer,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('home-search'),
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: widget.onSearch,
                    decoration: InputDecoration(
                      hintText: '¿Qué objeto perdiste?',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Buscar en Explorar',
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () => widget.onSearch(_search.text),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: widget.onNewReport,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Publicar hallazgo'),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: colors.secondary, width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Encontrados recientemente',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Una segunda oportunidad para volver a casa.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CommunityResults(
                    reports: context
                        .watch<ReportsViewModel>()
                        .communityFound
                        .take(6)
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
