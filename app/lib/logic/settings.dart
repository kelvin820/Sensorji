import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import 'draw.dart';
import 'season.dart';
import 'shake.dart';
import 'sounds.dart';

enum Tone {
  gentle('溫和'),
  direct('直白'),
  brief('簡短');

  const Tone(this.label);
  final String label;
}

enum InputMode {
  typing('打字'),
  voice('搖籤時用說的');

  const InputMode(this.label);
  final String label;
}

/// 設定頁的所有選項（BUILD_PLAN 第 4 節 10 設定），存在本機。
class Settings extends ChangeNotifier {
  Settings(this._prefs) {
    Sounds.enabled = sound;
  }

  final SharedPreferences _prefs;

  static Future<Settings> load() async => Settings(await SharedPreferences.getInstance());

  T _enum<T extends Enum>(String key, List<T> values, T fallback) {
    final name = _prefs.getString(key);
    return values.firstWhere((v) => v.name == name, orElse: () => fallback);
  }

  Future<void> _setEnum(String key, Enum v) async {
    await _prefs.setString(key, v.name);
    notifyListeners();
  }

  JiaobeiMode get jiaobei => _enum('jiaobei', JiaobeiMode.values, JiaobeiMode.none);
  set jiaobei(JiaobeiMode v) => _setEnum('jiaobei', v);

  SeasonMode get seasonMode => _enum('seasonMode', SeasonMode.values, SeasonMode.byHour);
  set seasonMode(SeasonMode v) => _setEnum('seasonMode', v);

  Season get fixedSeason => _enum('fixedSeason', Season.values, Season.autumn);
  set fixedSeason(Season v) => _setEnum('fixedSeason', v);

  ShakeSensitivity get sensitivity =>
      _enum('sensitivity', ShakeSensitivity.values, ShakeSensitivity.medium);
  set sensitivity(ShakeSensitivity v) => _setEnum('sensitivity', v);

  Tone get tone => _enum('tone', Tone.values, Tone.gentle);
  set tone(Tone v) => _setEnum('tone', v);

  Deck get defaultDeck => _enum('defaultDeck', Deck.values, Deck.sensoji);
  set defaultDeck(Deck v) => _setEnum('defaultDeck', v);

  InputMode get defaultInput => _enum('defaultInput', InputMode.values, InputMode.typing);
  set defaultInput(InputMode v) => _setEnum('defaultInput', v);

  bool get haptics => _prefs.getBool('haptics') ?? true;
  set haptics(bool v) {
    _prefs.setBool('haptics', v);
    notifyListeners();
  }

  /// 音效（竹籤聲、磬、抽屜、紙張、風鈴、筊杯落地）。
  bool get sound => _prefs.getBool('sound') ?? true;
  set sound(bool v) {
    _prefs.setBool('sound', v);
    Sounds.enabled = v;
    notifyListeners();
  }

  Season currentSeason([DateTime? now]) =>
      resolveSeason(seasonMode, now ?? DateTime.now(), fixedSeason);
}
