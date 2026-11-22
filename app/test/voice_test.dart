import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensoji/logic/voice.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

/// 假的系統辨識器：可以模擬 Android 在 stop 之後才送出（或送出空的）最終結果。
class FakeStt extends SpeechToTextPlatform {
  /// stop() 期間送出的最終結果（null 表示不送）。
  String? finalDuringStop;

  /// stop() 回來之後多久才送最終結果（null 表示不送）。
  Duration? finalDelay;
  String finalLater = '';

  void say(String words, {bool last = false}) => onTextRecognition?.call(jsonEncode({
        'alternates': [
          {'recognizedWords': words, 'confidence': 0.9},
        ],
        'resultType': last ? 2 : 1, // 1 = partial, 2 = final
      }));

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> initialize({debugLogging = false, List<SpeechConfigOption>? options}) async => true;
  @override
  Future<List<dynamic>> locales() async => [];
  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async {
    if (finalDuringStop != null) say(finalDuringStop!, last: true);
    if (finalDelay != null) {
      Timer(finalDelay!, () {
        say(finalLater, last: true);
        onStatus?.call('done');
      });
    }
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // speech_to_text 是單例，只會綁定第一次 initialize 時的平台物件，所以整個檔案共用一個假辨識器。
  final stt = FakeStt();
  SpeechToTextPlatform.instance = stt;
  late SpeechVoiceInput voice;

  setUp(() async {
    stt
      ..finalDuringStop = null
      ..finalDelay = null
      ..finalLater = '';
    voice = SpeechVoiceInput();
    expect(await voice.start(), isTrue);
  });

  test('stop 期間送來空的最終結果：保留畫面上已聽到的字', () async {
    stt.say('明年換工作好嗎');
    expect(voice.text, '明年換工作好嗎');
    stt.finalDuringStop = '';
    expect(await voice.stop(), '明年換工作好嗎');
  });

  test('最終結果在 stop 之後才到：等它並採用完整版', () async {
    stt.say('明年換');
    stt
      ..finalDelay = const Duration(milliseconds: 300)
      ..finalLater = '明年換工作好嗎';
    expect(await voice.stop(), '明年換工作好嗎');
  });

  test('一直沒有最終結果：逾時後用畫面上的字', () async {
    stt.say('明年換工作好嗎');
    expect(await voice.stop(), '明年換工作好嗎');
  });

  test('最終結果比畫面上的字短（被截掉）：不採用', () async {
    stt.say('明年換工作好嗎');
    stt
      ..finalDelay = const Duration(milliseconds: 100)
      ..finalLater = '明年';
    expect(await voice.stop(), '明年換工作好嗎');
  });
}
