import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/logic/interpret_client.dart';
import 'package:sensoji/ui/widgets/slip_unfold.dart';

Future<void> pumpSlip(WidgetTester tester, {required bool play, bool reduced = false}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduced);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(MaterialApp(
    home: Center(child: SlipUnfold(play: play, child: const SizedBox(width: 100, height: 150, child: Text('籤')))),
  ));
}

void main() {
  testWidgets('④ 剛抽到：先對折（兩份半張＋不能點），播完變回原本的籤紙', (tester) async {
    await pumpSlip(tester, play: true);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(IgnorePointer), findsWidgets);
    expect(find.text('籤'), findsWidgets);
    await tester.pump(kSlipAnimDuration);
    expect(find.text('籤'), findsOneWidget, reason: '攤平後只剩原本的籤紙');
  });

  testWidgets('從紀錄回看或減少動態效果：直接攤平', (tester) async {
    await pumpSlip(tester, play: false);
    expect(find.text('籤'), findsOneWidget);
    await pumpSlip(tester, play: true, reduced: true);
    await tester.pumpAndSettle();
    expect(find.text('籤'), findsOneWidget);
  });

  test('App 沒給 API_BASE 時用已部署的解籤服務', () {
    expect(apiBase, kDeployedApi);
  });
}
