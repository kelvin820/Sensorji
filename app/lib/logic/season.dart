/// 季節服務（BUILD_PLAN 第 1 節「季節切換」）。
library;

enum Season {
  spring('春', 'spring'),
  summerNoon('夏・正午', 'summer_noon'),
  summer('夏・午後', 'summer'),
  autumn('秋', 'autumn'),
  winter('冬・夜', 'winter');

  const Season(this.label, this.suffix);
  final String label;

  /// 背景檔名後綴，例：BG03_autumn.webp。
  final String suffix;

  bool get isNight => this == Season.winter;
  bool get isSummer => this == Season.summer || this == Season.summerNoon;

  /// 背景圖：scene 為 1–6。
  String background(int scene, {bool noLantern = false}) =>
      'assets/bg/BG0${scene}_$suffix${noLantern ? '_nolantern' : ''}.webp';

  /// 當季飄落物（香煙 DE05 另外處理，四季共用）。
  List<String> get particles => switch (this) {
        Season.spring => _sprites('DE03'),
        Season.summerNoon || Season.summer => _sprites('DE06'),
        Season.autumn => [..._sprites('DE01'), ..._sprites('DE02')],
        Season.winter => _sprites('DE04'),
      };

  static List<String> _sprites(String id) =>
      [for (var i = 1; i <= 5; i++) 'assets/sprites/${id}_$i.webp'];

  static Season? fromSuffix(String? s) {
    for (final v in Season.values) {
      if (v.suffix == s) return v;
    }
    return null;
  }
}

enum SeasonMode {
  byHour('依時辰'),
  byMonth('依真實季節'),
  fixed('固定某一季');

  const SeasonMode(this.label);
  final String label;
}

/// 夏季依時間分正午（11:00–13:59）與午後。
Season _summerFor(int hour) => hour >= 11 && hour < 14 ? Season.summerNoon : Season.summer;

/// 依時辰：晨 05–10 春、午 11–15 夏、暮 16–18 秋、夜 19–04 冬。
Season seasonByHour(DateTime t) {
  final h = t.hour;
  if (h >= 5 && h < 11) return Season.spring;
  if (h >= 11 && h < 16) return _summerFor(h);
  if (h >= 16 && h < 19) return Season.autumn;
  return Season.winter;
}

/// 依真實季節：春 3–5、夏 6–9、秋 10–11、冬 12–2 月。
Season seasonByMonth(DateTime t) {
  final m = t.month;
  if (m >= 3 && m <= 5) return Season.spring;
  if (m >= 6 && m <= 9) return _summerFor(t.hour);
  if (m >= 10 && m <= 11) return Season.autumn;
  return Season.winter;
}

Season resolveSeason(SeasonMode mode, DateTime now, Season fixed) => switch (mode) {
      SeasonMode.byHour => seasonByHour(now),
      SeasonMode.byMonth => seasonByMonth(now),
      SeasonMode.fixed => fixed.isSummer ? _summerFor(now.hour) : fixed,
    };
