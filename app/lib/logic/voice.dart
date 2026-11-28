import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 語音提問（BUILD_PLAN 第 7 節）：在搖籤頁按住音量鍵（或「按住說話」）時聆聽，
/// 即時把辨識文字顯示出來；放開就當作問題講完，籤落下。
///
/// Android 用系統的 SpeechRecognizer，Web 用瀏覽器的 Web Speech API（Chrome 支援）；
/// 兩者都會把聲音送到 Google 辨識，隱私權政策需載明。
abstract class VoiceInput extends ChangeNotifier {
  /// 目前為止的辨識結果（已確定的句子＋正在說的句子）。
  String get text;
  bool get listening;

  /// 目前的音量（0–1），用來畫音量條；平台不提供時是 null（Web）。
  double? get level => null;

  /// 準備麥克風（第一次會跳出權限要求）。回傳 false 表示無法使用
  /// （沒有麥克風權限、裝置或瀏覽器不支援）。在提問頁按「開始搖籤」時呼叫。
  Future<bool> prepare();

  /// 開始聆聽（可以多次按住、放開；文字會接在後面）。回傳 false 表示無法開始。
  Future<bool> start();

  /// 清空上一次的文字。
  void reset();

  /// 停止聆聽，回傳最終文字。
  Future<String> stop();
}

class SpeechVoiceInput extends VoiceInput {
  final _stt = SpeechToText();
  bool _ready = false;
  bool _wanted = false; // 使用者還在搖籤畫面，辨識器自己停下時要接著聽
  int _restarts = 0;
  String _done = ''; // 前幾段已確定的文字
  String _partial = '';
  double _level = 0;

  static const _maxRestarts = 6;

  /// 放開後最多等辨識器送來最終結果的時間。
  static const _finalWait = Duration(milliseconds: 1500);

  /// stop() 等待中的最終結果。
  Completer<void>? _final;

  @override
  String get text => _join(_done, _partial);

  @override
  bool get listening => _stt.isListening;

  /// Android 的 SpeechRecognizer 回報約 -2～10（dB 的相對值）；Web 不提供音量。
  @override
  double? get level => kIsWeb ? null : (_stt.isListening ? _level : 0);

  String get _locale => kIsWeb ? 'zh-TW' : 'zh_TW';

  @override
  Future<bool> prepare() async {
    try {
      _ready = _ready || await _stt.initialize(onStatus: _onStatus, onError: _onError);
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  @override
  void reset() {
    _done = '';
    _partial = '';
    notifyListeners();
  }

  @override
  Future<bool> start() async {
    if (!await prepare()) return false;
    if (_stt.isListening) return true;
    _restarts = 0;
    _wanted = true;
    await _listen();
    return true;
  }

  Future<void> _listen() async {
    try {
      await _stt.listen(
        onResult: _onResult,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          partialResults: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 8),
          cancelOnError: false,
        ),
      );
    } catch (_) {
      _wanted = false;
    }
    notifyListeners();
  }

  void _onLevel(double db) {
    final v = ((db + 2) / 12).clamp(0.0, 1.0);
    // 往上快、往下慢，音量條才不會一直抖
    _level = v > _level ? v : _level * 0.7 + v * 0.3;
    notifyListeners();
  }

  void _onResult(SpeechRecognitionResult r) {
    if (r.finalResult) {
      // 有些辨識器的最終結果是空的，不能拿它蓋掉畫面上已經聽到的字。
      _done = _join(_done, r.recognizedWords.trim().isEmpty ? _partial : r.recognizedWords);
      _partial = '';
      _final?.complete();
      _final = null;
    } else if (r.recognizedWords.trim().isNotEmpty) {
      _partial = r.recognizedWords;
    }
    notifyListeners();
  }

  void _onStatus(String status) {
    if (status == 'done' && _final != null) {
      _final!.complete();
      _final = null;
    }
    // 使用者停頓太久時系統會自己結束，人還在搖籤就再聽下一段。
    if ((status == 'done' || status == 'notListening') && _wanted && _restarts < _maxRestarts) {
      _restarts++;
      _done = _join(_done, _partial);
      _partial = '';
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_wanted && !_stt.isListening) _listen();
      });
    }
    notifyListeners();
  }

  void _onError(SpeechRecognitionError e) {
    // 權限被拒或辨識器無法使用時不再重試；沒聽到聲音（no_match）可以再聽。
    if (e.permanent && !e.errorMsg.contains('no_match') && !e.errorMsg.contains('speech_timeout')) {
      _wanted = false;
    }
    notifyListeners();
  }

  /// 停止並回傳最終文字。
  ///
  /// Android 的 stop() 回來時最終結果通常還沒到（之後才非同步送來），
  /// 中間還可能先送一筆空的暫時結果；直接讀文字會拿到空字串，問題就沒帶到籤號頁。
  /// 所以先記下畫面上顯示的文字，再等最終結果（最多 1.5 秒），取比較完整的那份。
  @override
  Future<String> stop() async {
    _wanted = false;
    final shown = text;
    if (_stt.isListening) {
      final pending = _final = Completer<void>();
      await _stt.stop();
      await pending.future.timeout(_finalWait, onTimeout: () {});
      _final = null;
    }
    final heard = text;
    _done = heard.length >= shown.length ? heard : shown;
    _partial = '';
    notifyListeners();
    return _done;
  }

  static String _join(String a, String b) {
    if (a.isEmpty) return b.trim();
    if (b.trim().isEmpty) return a;
    return '$a，${b.trim()}';
  }
}
