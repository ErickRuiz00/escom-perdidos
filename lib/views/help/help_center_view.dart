import 'package:flutter/material.dart';
import '../recovery/recovery_hub_view.dart';
import '../widgets/common.dart';
import 'tutorial_view.dart';

const _faqs = [
  (
    'Publicaciones',
    '¿Qué puedo publicar?',
    'Publica objetos encontrados en ESCOM. Usa una descripción útil, fecha, zona y custodia. Evita fotos de credenciales legibles, teléfonos, boletas u otros datos personales. Si perdiste algo, empieza en Explorar.',
  ),
  (
    'Mis hallazgos',
    '¿Puedo corregir o retirar un hallazgo?',
    'En Perfil → Mis hallazgos encontrarás tus publicaciones. Puedes corregir datos mientras estén activas o retirarlas. Retirar cierra las solicitudes y conversaciones de esa publicación; el historial de solicitudes se conserva.',
  ),
  (
    'Recuperación',
    '¿Cómo funciona «Creo que es mío»?',
    'Abre un hallazgo activo bajo custodia de un estudiante y envía características privadas que ayuden a reconocerlo. La evidencia solo la ven el solicitante y el encontrador. Consulta después la solicitud en Chats.',
  ),
  (
    'Verificación de propiedad',
    '¿Aceptar una solicitud acredita al propietario?',
    'No. La aceptación permite conversar. Comprueba características que no sean públicas y pide solo información necesaria para reconocer el objeto. No compartas contraseñas, códigos, datos bancarios ni fotografías de documentos completos.',
  ),
  (
    'Chats',
    '¿Quién puede leer el chat y por qué se cerró?',
    'El chat es privado para los dos participantes de una solicitud aceptada. Se cierra al resolver la devolución, retirar el hallazgo, declarar Prefectura o cerrar la comunicación. Consulta el motivo en la solicitud. Coordina una entrega en un lugar público y evita lugares aislados.',
  ),
  (
    'Devoluciones',
    '¿Cómo confirmo una entrega?',
    'Después de la entrega física, el encontrador toca «Confirmar que entregué» y el solicitante «Confirmar que recibí». Una sola confirmación no resuelve el hallazgo. Al confirmar ambos se cierran las demás solicitudes del objeto.',
  ),
  (
    'Prefectura',
    '¿Qué significa «Entrega declarada a Prefectura»?',
    'Es una declaración de quien publica, no una verificación digital de Prefectura. Consulta presencialmente al personal y aporta información que ayude a identificar el objeto. Verifica allí los horarios, ubicación de atención y requisitos vigentes. La app no ofrece chat ni confirma recepciones en nombre de Prefectura.',
  ),
  (
    'Notificaciones',
    '¿Recibo avisos con la app cerrada?',
    'Estos avisos funcionan dentro de la aplicación. Mientras estás conectado se actualizan en tiempo real y al volver se recupera el historial. Desde Configuración puedes silenciar categorías para eventos futuros. Los eventos permanecen consultables, aunque no cuenten como avisos sin leer.',
  ),
  (
    'Coincidencias',
    '¿Ya hay coincidencias automáticas?',
    'Todavía no. Puedes guardar tu preferencia para cuando exista esa función. Mientras tanto, utiliza los filtros de Explorar y verifica las características del objeto.',
  ),
  (
    'Seguridad y abuso',
    '¿Cómo reporto una conducta inapropiada?',
    'Abre la solicitud correspondiente y toca Reportar abuso. Ese es el mismo reporte disponible desde el chat a través de su solicitud. Describe lo ocurrido sin incluir contraseñas ni datos innecesarios. El reporte es privado para quien lo envía; el proyecto aún no ofrece atención automática ni un plazo garantizado de respuesta.',
  ),
];

class HelpCenterView extends StatelessWidget {
  const HelpCenterView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Centro de ayuda')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ConstrainedContent(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Cómo podemos orientarte?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Guía de uso de la aplicación. Consulta con el personal cualquier información oficial de ESCOM.',
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.explore_outlined),
                    title: const Text('Ver tutorial'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => startSectionTutorial(context),
                  ),
                ),
                for (final (topic, question, answer) in _faqs)
                  Card(
                    child: ExpansionTile(
                      key: PageStorageKey(topic),
                      title: Text(topic),
                      subtitle: Text(question),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      children: [Text(answer)],
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Para reportar abuso, abre la solicitud y toca Reportar abuso.',
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecoveryHubView(),
                    ),
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Ir a mis solicitudes para reportar abuso'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
