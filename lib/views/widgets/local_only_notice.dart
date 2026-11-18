import 'package:flutter/material.dart';

class LocalOnlyNotice extends StatelessWidget {
  const LocalOnlyNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Por ahora, tu hallazgo se guarda solo en este dispositivo. Aún no será visible para otras personas.',
        style: TextStyle(color: colors.onSecondaryContainer),
      ),
    );
  }
}
