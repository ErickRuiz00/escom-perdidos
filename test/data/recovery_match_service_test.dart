import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/data/services/recovery_match_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'found_items_repository_test.dart' show fixture, other, uid;

void main() {
  test(
    'sin backend de publicaciones perdidas no inventa coincidencias',
    () async {
      final service = RecoveryMatchService()..bindUser(uid);
      expect(service.available, isFalse);
      expect(await service.suggestions(fixture(owner: other)), isEmpty);
    },
  );
  test(
    'origen futuro prioriza zona/fecha, permite descartar y aísla cuenta',
    () async {
      final lost = fixture().copyWith(type: ReportType.lost);
      final service = RecoveryMatchService(lostPublications: () async => [lost])
        ..bindUser(uid);
      final found = fixture(owner: other, identifier: 'found');
      expect(await service.suggestions(found), [lost]);
      service.dismiss(lost.id, found.id);
      expect(await service.suggestions(found), isEmpty);
      service.bindUser(other);
      expect(await service.suggestions(found), isEmpty);
      service.bindUser(uid);
      expect(await service.suggestions(found), [lost]);
    },
  );
}
