/// 音效：tools/synth_sounds.py 用程式合成的短音（assets/sounds/*.wav），沒有外部素材。
/// 用 audioplayers（Android 與網頁版都支援）。每種音效有幾個播放器輪流用，
/// 快速連續播（搖籤時竹籤一直碰）也不會互相切掉。
/// [Sounds.enabled] 跟著設定頁的「音效」開關（main 裡接好）。播放失敗一律忽略：音效不能讓 App 出錯。
library;

import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Sfx {
  clack1('clack_1', 3),
  clack2('clack_2', 3),
  clack3('clack_3', 3),
  stickLand('stick_land'),
  bell('bell'),
  drawer('drawer'),
  unfold('unfold'),
  fold('fold', 3),
  chime('chime'),
  jiaoHeavy('jiao_heavy', 2),
  jiaoLight('jiao_light', 3),
  furin('furin', 2);

  const Sfx(this.file, [this.voices = 1]);
  final String file;

  /// 同時能響幾個（輪流用的播放器數）。
  final int voices;

  static const clacks = [clack1, clack2, clack3];
}

class Sounds {
  /// 設定頁的「音效」開關。
  static bool enabled = true;

  /// 測試環境沒有音訊外掛：不建立播放器。
  static final bool _available = kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

  static final Map<Sfx, List<AudioPlayer>> _players = {};
  static final Map<Sfx, int> _next = {};

  static AudioPlayer _player(Sfx s) {
    final list = _players.putIfAbsent(s, () => []);
    final i = _next[s] ?? 0;
    _next[s] = (i + 1) % s.voices;
    if (i < list.length) return list[i];
    final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    list.add(p);
    return p;
  }

  /// 播一次。[volume] 0…1；[delay] 晚一點再播（關掉音效時連計時器都不建）。
  static Future<void> play(Sfx s, {double volume = 1, Duration delay = Duration.zero}) async {
    if (!enabled || !_available) return;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    try {
      final p = _player(s);
      await p.stop();
      await p.play(AssetSource('sounds/${s.file}.wav'), volume: volume.clamp(0.0, 1.0), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('sound ${s.file}: $e');
    }
  }

  static int _clack = 0;

  /// 竹籤互碰：三種輪流，力道決定音量。
  static Future<void> clack(double intensity) =>
      play(Sfx.clacks[_clack++ % Sfx.clacks.length], volume: 0.45 + 0.55 * intensity.clamp(0.0, 1.0));
}
