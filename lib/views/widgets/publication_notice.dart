import 'package:flutter/material.dart';

class PublicationNotice extends StatelessWidget {
  const PublicationNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Comparte solo objetos encontrados. La comunidad podrá consultar tu publicación; tus datos de perfil permanecen privados.',
        style: TextStyle(color: colors.onTertiaryContainer),
      ),
    );
  }
}
