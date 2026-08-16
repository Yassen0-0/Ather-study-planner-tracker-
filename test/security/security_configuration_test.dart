import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android backup/data-transfer is disabled for private local data', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('FlutterFire configuration targets the shipped Android application', () {
    final firebaseJson = jsonDecode(File('firebase.json').readAsStringSync())
        as Map<String, Object?>;
    final flutter = firebaseJson['flutter']! as Map<String, Object?>;
    final platforms = flutter['platforms']! as Map<String, Object?>;
    final android = platforms['android']! as Map<String, Object?>;
    final androidDefault = android['default']! as Map<String, Object?>;
    final dart = platforms['dart']! as Map<String, Object?>;
    final options = dart['lib/firebase_options.dart']! as Map<String, Object?>;
    final configurations = options['configurations']! as Map<String, Object?>;

    expect(androidDefault['appId'], '1:882606725720:android:f7e9109d4620e84420c82d');
    expect(configurations['android'], androidDefault['appId']);
  });
}
