import 'package:escom_perdidos/data/services/auth_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'queues cold callback once and accepts only the app Auth paths',
    () async {
      final links = AuthLinkService();
      addTearDown(links.dispose);
      final valid = Uri.parse(
        '${AuthLinkService.confirmationRedirect}#type=signup',
      );
      links.receive(valid);
      expect(links.takePending(), valid);
      links.receive(valid);
      expect(links.takePending(), isNull);
      for (final url in [
        'https://other.example/auth/recovery',
        'mx.ipn.escom.encuentralo://evil/recovery',
        'mx.ipn.escom.encuentralo://auth/reports',
        'mx.ipn.escom.encuentralo://auth:123/recovery',
      ]) {
        links.receive(Uri.parse(url));
        expect(links.hasPending, isFalse);
      }
      links.receive(Uri.parse(AuthLinkService.recoveryRedirect));
      expect(links.takePending()?.path, '/recovery');
    },
  );
}
