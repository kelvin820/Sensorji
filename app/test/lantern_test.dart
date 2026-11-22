import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/ui/widgets/lantern.dart';

const _sei = AssetImage('assets/objects/OB01_sei.webp');

Future<void> pumpLantern(WidgetTester tester, {required bool reduced}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduced);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(const MaterialApp(home: Stack(children: [GoodLantern()])));
}

double opacityOf(WidgetTester tester) =>
    tester.widget<FadeTransition>(
      find.ancestor(of: find.image(_sei), matching: find.byType(FadeTransition)).first,
    ).opacity.value;

double angleOf(WidgetTester tester) {
  final t = tester.widget<Transform>(
    find.ancestor(of: find.image(_sei), matching: find.byType(Transform)).first,
  );
  // 旋轉矩陣的 sin 分量
  return t.transform.storage[1];
}

void main() {
  testWidgets('一般：延遲後從畫面上方降下、停住後慢擺', (tester) async {
    await pumpLantern(tester, reduced: false);
    final start = tester.getRect(find.image(_sei));
    expect(start.bottom, lessThanOrEqualTo(0), reason: '一開始在畫面外');

    await tester.pump(kSlipUnfoldDuration + kGoodLanternDelay - const Duration(milliseconds: 50));
    expect(tester.getRect(find.image(_sei)).bottom, lessThanOrEqualTo(2), reason: '籤紙展開後 0.4 秒前還沒降下');

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(kGoodLanternDrop);
    final rest = tester.getRect(find.image(_sei));
    expect(rest.top, greaterThan(-rest.height * 0.05), reason: '已降到定位');

    final a1 = angleOf(tester);
    await tester.pump(const Duration(milliseconds: 1500)); // 四分之一週期
    final a2 = angleOf(tester);
    expect((a2 - a1).abs(), greaterThan(0.01), reason: '持續擺動');
    expect(a2.abs(), lessThanOrEqualTo(0.0262 + 1e-3), reason: '幅度 ±1.5°');

    await tester.pumpWidget(const SizedBox()); // 停掉無限動畫
  });

  testWidgets('減少動態效果：不降下、不擺動，直接淡入靜止', (tester) async {
    await pumpLantern(tester, reduced: true);
    final at0 = tester.getRect(find.image(_sei));
    expect(at0.top, greaterThan(0), reason: '一開始就在定位');
    expect(opacityOf(tester), lessThan(1));
    await tester.pumpAndSettle(); // 沒有無限動畫，能停下來
    expect(opacityOf(tester), 1);
    expect(tester.getRect(find.image(_sei)), at0);
    expect(angleOf(tester), 0);
  });
}
