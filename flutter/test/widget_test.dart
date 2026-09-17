import 'package:flutter_test/flutter_test.dart';

import 'package:attendor_dashboard/models.dart';

void main() {
  test('UserMeta parses role from snapshot', () {
    final meta = UserMeta.fromSnapshot('u1', {'role': 'student', 'schoolId': 's1', 'classId': 'c1'});
    expect(meta?.role, Role.student);
    expect(meta?.schoolId, 's1');
  });

  test('UserMeta returns null without valid role', () {
    expect(UserMeta.fromSnapshot('u1', null), isNull);
  });
}