import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../viewmodels/weather_viewmodel.dart';
import 'skeleton.dart';

/// Tarjeta con el clima del campus. Muestra el dato en caché si no hay red.
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeatherViewModel>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final weather = vm.weather;

    Widget content;
    if (weather == null && vm.loading) {
      content = const Row(children: [
        Skeleton(width: 40, height: 40, radius: 20),
        SizedBox(width: 12),
        Expanded(child: Skeleton(height: 16)),
      ]);
    } else if (weather == null) {
      content = Row(children: [
        Icon(Icons.cloud_off_rounded, color: colors.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: Text(vm.error ?? 'Clima no disponible')),
        TextButton(onPressed: vm.load, child: const Text('Reintentar')),
      ]);
    } else {
      content = Row(children: [
        Icon(
          weather.rainLikely ? Icons.umbrella_rounded : Icons.wb_sunny_rounded,
          size: 36,
          color: colors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${weather.temperature.round()}° · ${weather.description} en ESCOM',
                style: theme.textTheme.titleSmall,
              ),
              Text(weather.tip, style: theme.textTheme.bodySmall),
              if (weather.fromCache)
                Text(
                  'Sin conexión · dato de ${Formatters.relative(weather.fetchedAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.error),
                ),
            ],
          ),
        ),
      ]);
    }

    return Card(
      color: colors.primaryContainer.withValues(alpha: 0.45),
      child: Padding(padding: const EdgeInsets.all(14), child: content),
    );
  }
}
