// 版面測試（BUILD_PLAN 第 11 節「Widget／Golden 測試」）：主要畫面在 390×844 與 360×800、
// 秋（白天）／夏（有風鈴、酸漿）／冬夜三種外觀下都排得下——RenderFlex 溢位等版面錯誤會讓測試失敗。
//
// 沒有做像素比對的 golden：測試環境沒有中文字型（完整字型檔太大不進版控），截圖只會是方塊，
// 比對不出有意義的差異；版面錯誤由這裡抓，視覺由實機看。
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/app/scope.dart';
import 'package:sensoji/app/theme.dart';
import 'package:sensoji/main.dart';
import 'package:sensoji/ui/screens/home_screen.dart';
import 'package:sensoji/ui/widgets/summer_decor.dart';

import 'flow_test.dart' show FixedDraw, FakeVoice, loadPoems, makeServices;

const sizes = {'390×844': Size(390, 844), '360×800': Size(360, 800)};
const seasons = ['autumn', 'summer', 'winter'];

Future<AppServices> pumpAt(WidgetTester tester, Size size, String season,
    {bool reducedMotion = true, Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  if (reducedMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final s = await makeServices(FixedDraw(3), prefs: {'fixedSeason': season, ...prefs}, voice: FakeVoice('問句'));
  await tester.pumpWidget(SensojiApp(services: s));
  // 動畫開著時燈籠、風鈴永遠在動，不能等「靜止」
  reducedMotion ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 100));
  return s;
}

Future<void> open(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(HomeScreen))).push(path);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useGoogleFonts = false;
  setUpAll(loadPoems);

  for (final MapEntry(key: label, value: size) in sizes.entries) {
    for (final season in seasons) {
      group('$label $season', () {
        testWidgets('首頁、提問、紀錄、設定、隱私權政策', (tester) async {
          await pumpAt(tester, size, season);
          expect(find.text('開始求籤'), findsOneWidget);
          for (final path in ['/ask', '/records', '/settings', '/privacy']) {
            await open(tester, path);
            expect(tester.takeException(), isNull, reason: path);
            Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
            await tester.pumpAndSettle();
          }
        });

        testWidgets('搖籤（打字／語音）→ 籤號 → 籤詩 → 結籤', (tester) async {
          final s = await pumpAt(tester, size, season, prefs: {'micExplained': true});
          await tester.tap(find.text('開始求籤'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('失物'));
          await tester.pumpAndSettle();

          // 語音模式的搖籤頁（按鈕最多的版面）
          await tester.ensureVisible(find.text('搖籤時用說的'));
          await tester.tap(find.text('搖籤時用說的'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('開始搖籤'));
          await tester.tap(find.text('開始搖籤'));
          await tester.pumpAndSettle();
          expect(find.text('停止錄音，改打字'), findsOneWidget);
          if (season == 'summer') expect(find.byType(WindChime), findsOneWidget);
          await tester.tap(find.text('停止錄音，改打字'));
          await tester.pumpAndSettle();

          // 打字模式 → 抽籤
          await tester.ensureVisible(find.text('開始搖籤'));
          await tester.tap(find.text('開始搖籤'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('無法搖晃？點此抽籤'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('看籤詩'));
          await tester.pumpAndSettle();
          expect(find.text('第 3 籤・凶'), findsOneWidget);

          await tester.ensureVisible(find.text('結籤：把籤繫在籤架上'));
          await tester.tap(find.text('結籤：把籤繫在籤架上'));
          await tester.pumpAndSettle();
          expect(find.text('幫我折好、結上'), findsOneWidget);
          expect(find.byType(Hozuki), findsNWidgets(season == 'summer' ? 1 : 0));
          expect(s.records.all, hasLength(1));
        });
      });
    }
  }

  testWidgets('無障礙：首頁、提問、設定的按鈕觸控區夠大、有標籤', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, sizes['360×800']!, 'autumn');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    for (final path in ['/ask', '/settings']) {
      await open(tester, path);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: path);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: path);
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();
    }
    handle.dispose();
  });

  testWidgets('夏季風鈴平常微微擺動；「減少動態效果」時靜止', (tester) async {
    await pumpAt(tester, sizes['390×844']!, 'summer', reducedMotion: false);
    final chime = tester.state<PendulumState>(find.byType(Pendulum).first);
    await tester.pump(const Duration(milliseconds: 700));
    expect(chime.angle, isNot(0));
    chime.kick(1);
    await tester.pump(const Duration(milliseconds: 190)); // 被推一下後約四分之一個擺盪週期
    expect(chime.angle.abs(), greaterThan(0.1));
    await tester.pumpWidget(const SizedBox()); // 停掉無限循環的動畫

    await pumpAt(tester, sizes['390×844']!, 'summer');
    final still = tester.state<PendulumState>(find.byType(Pendulum).first);
    still.kick(1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(still.angle, 0);
  });
}
