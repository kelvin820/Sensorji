import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensoji/logic/settings.dart';
import 'package:sensoji/logic/sounds.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('每個音效都有對應的 wav 檔，且已列入 pubspec 資產', () {
    for (final s in Sfx.values) {
      final f = File('assets/sounds/${s.file}.wav');
      expect(f.existsSync(), isTrue, reason: s.file);
      final head = f.readAsBytesSync().sublist(0, 4);
      expect(String.fromCharCodes(head), 'RIFF');
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/sounds/'));
  });

  test('設定頁的音效開關會同步到 Sounds.enabled，預設開', () async {
    SharedPreferences.setMockInitialValues({});
    final st = await Settings.load();
    expect(st.sound, isTrue);
    expect(Sounds.enabled, isTrue);
    st.sound = false;
    expect(Sounds.enabled, isFalse);
    expect((await Settings.load()).sound, isFalse);
    expect(Sounds.enabled, isFalse);
    st.sound = true;
  });

  test('測試環境沒有音訊外掛：播放直接略過、不會丟錯', () async {
    await Sounds.play(Sfx.bell, delay: const Duration(milliseconds: 1));
    await Sounds.clack(1);
  });
}
