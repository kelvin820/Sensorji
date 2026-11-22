import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/app/scope.dart';
import 'package:sensoji/app/theme.dart';
import 'package:sensoji/data/repository.dart';
import 'package:sensoji/logic/draw.dart';
import 'package:sensoji/logic/records.dart';
import 'package:sensoji/logic/season.dart';
import 'package:sensoji/logic/settings.dart';
import 'package:sensoji/logic/voice.dart';
import 'package:sensoji/main.dart';
import 'package:sensoji/ui/widgets/lantern.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 固定籤號的抽籤服務，讓流程測試可重現。
class FixedDraw extends DrawService {
  FixedDraw(this.number, [this.jiao = const []]) : super(Random(1));
  final int number;
  final List<JiaoResult> jiao;
  int _i = 0;

  @override
  int drawNumber(deck) => number;

  @override
  JiaoResult throwJiao() => jiao[_i++];
}

/// 籤詩資料在 setUpAll（真實時間）載入：大檔案用背景 isolate 解碼，
/// 在 testWidgets 的假時間裡不會完成。
late PoemRepository poems;

Future<void> loadPoems() async => poems = await PoemRepository.load(rootBundle);

/// 假的語音輸入：開始後「聽到」固定的一句話。
class FakeVoice extends VoiceInput {
  FakeVoice(this.heard, {this.available = true});
  final String heard;
  final bool available;
  String _text = '';
  bool _listening = false;
  bool stopped = false;

  @override
  String get text => _text;
  @override
  bool get listening => _listening;

  @override
  Future<bool> prepare() async => available;

  @override
  void reset() => _text = '';

  @override
  Future<bool> start() async {
    if (!available) return false;
    _listening = true;
    _text = heard;
    notifyListeners();
    return true;
  }

  @override
  Future<String> stop() async {
    _listening = false;
    stopped = true;
    notifyListeners();
    return _text;
  }
}

Future<AppServices> makeServices(DrawService draw,
    {Map<String, Object> prefs = const {}, VoiceInput? voice}) async {
  SharedPreferences.setMockInitialValues({'seasonMode': 'fixed', 'fixedSeason': 'autumn', ...prefs});
  return AppServices(
    poems: poems,
    settings: await Settings.load(),
    records: await RecordStore.load(),
    draw: draw,
    voice: voice ?? FakeVoice(''),
  );
}

Future<void> pumpApp(WidgetTester tester, AppServices s) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // 系統「減少動態效果」：關掉燈籠、香煙、粒子等無限循環動畫，畫面才會靜止。
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(SensojiApp(services: s));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useGoogleFonts = false;
  setUpAll(loadPoems);

  testWidgets('淺草寺：首頁 → 提問 → 點按抽籤 → 籤號 → 籤詩，並存成紀錄', (tester) async {
    final s = await makeServices(FixedDraw(3)); // 第 3 籤是凶
    await pumpApp(tester, s);

    await tester.tap(find.text('開始求籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('健康・病人'));
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '家人的身體會好轉嗎');
    await tester.pumpAndSettle();
    expect(find.text('家人的身體會好轉嗎'), findsOneWidget, reason: '提問框');
    await tester.ensureVisible(find.text('開始搖籤'));
    await tester.tap(find.text('開始搖籤'));
    await tester.pumpAndSettle();
    expect(find.text('「家人的身體會好轉嗎」'), findsOneWidget, reason: '搖籤畫面應顯示問題');

    await tester.tap(find.text('無法搖晃？點此抽籤'));
    await tester.pumpAndSettle();
    expect(find.text('第三籤'), findsOneWidget);
    expect(find.text('家人的身體會好轉嗎'), findsOneWidget, reason: '籤號畫面的問題框');

    await tester.tap(find.text('看籤詩'));
    await tester.pumpAndSettle();
    expect(find.text('第 3 籤・凶'), findsOneWidget);
    expect(find.text('請 AI 為我解籤'), findsOneWidget);
    expect(find.text('結籤：把籤繫在籤架上'), findsOneWidget, reason: '凶籤要提供結籤');
    expect(find.byType(GoodLantern), findsNothing, reason: '凶籤不出現「成」燈籠');

    // 逐句白話：點籤紙，四句白話一起浮出；按「收起」關掉。
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle();
    expect(find.text('愁惱損忠良'), findsOneWidget);
    expect(find.text('憂愁煩惱讓正直善良的人也受了折損。'), findsOneWidget);
    expect(find.text('多餘的掛慮反而讓日子顯得更漫長難熬。'), findsOneWidget, reason: '四句一起出');
    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(find.text('憂愁煩惱讓正直善良的人也受了折損。'), findsNothing);

    final r = s.records.all.single;
    expect(r.number, 3);
    expect(r.question, '家人的身體會好轉嗎');
    expect(r.season, Season.autumn);

    await tester.tap(find.text('結籤：把籤繫在籤架上'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('把籤結上'));
    await tester.pump(const Duration(milliseconds: 300)); // 一長一短震動的第二下
    await tester.pumpAndSettle();
    expect(s.records.all.single.tied, isTrue);
  });

  testWidgets('六十甲子籤：擲筊失敗重搖，第二次三聖杯通過', (tester) async {
    final s = await makeServices(
      FixedDraw(1, [JiaoResult.holy, JiaoResult.laughing, JiaoResult.holy, JiaoResult.holy, JiaoResult.holy]),
      prefs: {'defaultDeck': 'tw60', 'jiaobei': 'thrice'},
    );
    await pumpApp(tester, s);

    await tester.tap(find.text('開始求籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('心願・願望'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('開始搖籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('無法搖晃？點此抽籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('擲筊確認'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('擲筊'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('擲筊'));
    await tester.pumpAndSettle();
    expect(find.text('笑杯'), findsOneWidget);
    await tester.tap(find.text('重新搖籤'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 次求籤'), findsOneWidget);

    await tester.tap(find.text('無法搖晃？點此抽籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('擲筊確認'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('擲筊'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('看籤詩'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 籤・甲子'), findsOneWidget);
    expect(find.text('籤詩參考新港奉天宮版本'), findsOneWidget);
    expect(find.textContaining('結籤'), findsNothing, reason: '六十甲子籤沒有結籤');
    expect(find.byType(GoodLantern), findsNothing, reason: '六十甲子籤沒有吉凶，不出現「成」燈籠');

    // 逐句白話：直接點直排的句子（「日」只出現在第一句）。
    await tester.tap(find.text('日'));
    await tester.pumpAndSettle();
    expect(find.text('太陽一出來，風雲便自然散去。'), findsOneWidget);
    expect(find.text('萬事清淨吉祥，平安有保障。'), findsOneWidget, reason: '四句一起出');
  });

  /// 首頁 → 點按抽籤 → 籤詩頁。
  Future<void> drawToPoem(WidgetTester tester) async {
    await tester.tap(find.text('開始求籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('心願・願望'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('開始搖籤'));
    await tester.tap(find.text('開始搖籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('無法搖晃？點此抽籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('看籤詩'));
    await tester.pumpAndSettle();
  }

  for (final (number, rank) in [(1, '大吉'), (4, '吉')]) {
    testWidgets('好籤（$rank）：籤詩頁出現「成」燈籠，掛在籤紙右上角上；紀錄回看也有', (tester) async {
      final s = await makeServices(FixedDraw(number));
      await pumpApp(tester, s);
      await drawToPoem(tester);
      expect(find.text('第 $number 籤・$rank'), findsOneWidget);
      expect(find.byType(GoodLantern), findsOneWidget);
      expect(find.image(const AssetImage('assets/objects/OB01_sei.webp')), findsOneWidget);

      // 籤紙維持原本大小（不讓位），燈籠刻意與籤紙右上角重疊。
      final lantern = tester.getRect(find.image(const AssetImage('assets/objects/OB01_sei.webp')));
      final slip = tester.getRect(find.byType(InteractiveViewer));
      expect(slip.top, closeTo(kToolbarHeight, 1), reason: '籤紙區緊接在標題列下方');
      expect(lantern.overlaps(slip), isTrue);
      expect(lantern.width, closeTo(390 * kGoodLanternWidthFactor, 0.5));
      expect(lantern.right, lessThanOrEqualTo(390));

      // 從籤紀錄回看
      await tester.tap(find.byTooltip('回首頁'));
      await tester.pumpAndSettle();
      expect(find.byType(GoodLantern), findsNothing);
      await tester.tap(find.text('我的籤紀錄'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('第 $number 籤').first);
      await tester.pumpAndSettle();
      expect(find.byType(GoodLantern), findsOneWidget);
    });
  }

  testWidgets('首頁燈籠用已寫好「雷門」的圖，不再疊字', (tester) async {
    final s = await makeServices(FixedDraw(1));
    await pumpApp(tester, s);
    expect(find.image(const AssetImage('assets/objects/OB01_raimon.webp')), findsOneWidget);
    expect(find.text('雷門'), findsNothing);
  });

  testWidgets('語音提問：按住音量鍵說話、即時顯示，放開就落籤並填進問題框', (tester) async {
    final voice = FakeVoice('明年換工作好嗎');
    final s = await makeServices(FixedDraw(1), prefs: {'defaultInput': 'voice'}, voice: voice);
    await pumpApp(tester, s);

    await tester.tap(find.text('開始求籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作・事業'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('開始搖籤'));
    await tester.tap(find.text('開始搖籤'));
    await tester.pumpAndSettle();
    expect(find.text('按住音量鍵說出你的問題，邊說邊搖'), findsOneWidget);
    expect(find.text('正在聆聽…'), findsNothing, reason: '還沒按住就不收音');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.audioVolumeDown);
    await tester.pump();
    expect(find.text('正在聆聽…'), findsOneWidget);
    expect(find.text('「明年換工作好嗎」'), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.audioVolumeDown);
    await tester.pumpAndSettle();
    expect(voice.stopped, isTrue);
    expect(find.text('明年換工作好嗎'), findsOneWidget, reason: '籤號頁的問題框');
  });

  testWidgets('語音提問：也可以按「說完了，落籤」', (tester) async {
    final s = await makeServices(FixedDraw(1), prefs: {'defaultInput': 'voice'}, voice: FakeVoice(''));
    await pumpApp(tester, s);
    await tester.tap(find.text('開始求籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('心願・願望'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('開始搖籤'));
    await tester.tap(find.text('開始搖籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了，落籤'));
    await tester.pumpAndSettle();
    expect(find.text('第一籤'), findsOneWidget);
  });

  testWidgets('語音無法使用時改回打字', (tester) async {
    final s = await makeServices(FixedDraw(1),
        prefs: {'defaultInput': 'voice'}, voice: FakeVoice('', available: false));
    await pumpApp(tester, s);
    await tester.tap(find.text('開始求籤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('失物'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('開始搖籤'));
    await tester.tap(find.text('開始搖籤'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已改成打字'), findsOneWidget);
    expect(find.text('開始搖籤'), findsOneWidget, reason: '留在提問頁');
  });

  testWidgets('冬夜也能正常顯示首頁', (tester) async {
    final s = await makeServices(FixedDraw(1), prefs: {'fixedSeason': 'winter'});
    await pumpApp(tester, s);
    expect(find.text('開始求籤'), findsOneWidget);
    expect(find.text('籤詩僅供參考與慰藉'), findsOneWidget);
  });
}
