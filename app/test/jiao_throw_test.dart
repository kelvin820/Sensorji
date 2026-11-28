import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/logic/draw.dart';
import 'package:sensoji/ui/widgets/jiao_throw.dart';

int count(String name) => find
    .byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith('$name.webp'),
    )
    .evaluate()
    .length;

class Host extends StatefulWidget {
  const Host({super.key, required this.onLand, required this.onDone});
  final ValueChanged<int> onLand;
  final VoidCallback onDone;
  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  JiaoResult? result;
  int id = 0;
  void throwIt(JiaoResult r) => setState(() {
        result = r;
        id++;
      });
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: JiaoThrow(result: result, throwId: id, onLand: widget.onLand, onDone: widget.onDone),
          ),
        ),
      );
}

void main() {
  for (final reduced in [false, true]) {
    testWidgets('擲筊${reduced ? '（減少動態效果）' : ''}：每次都停定在指定結果，停定通知一次', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduced);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final lands = <int>[];
      var dones = 0;
      final key = GlobalKey<HostState>();
      await tester.pumpWidget(Host(key: key, onLand: lands.add, onDone: () => dones++));
      expect(count('OB05'), 1, reason: '還沒擲：拿在手上的一對');

      final expected = {
        JiaoResult.laughing: (2, 0),
        JiaoResult.negative: (0, 2),
        JiaoResult.holy: (1, 1),
      };
      var n = 0;
      for (final MapEntry(key: r, value: (flat, round)) in expected.entries) {
        key.currentState!.throwIt(r);
        await tester.pump();
        if (!reduced) {
          await tester.pump(kJiaoThrowDuration * 0.3);
          expect(dones, n, reason: '還在空中');
        }
        await tester.pumpAndSettle();
        n++;
        expect(dones, n, reason: '$r 停定');
        expect((count('OB05_flat'), count('OB05_round')), (flat, round), reason: '$r 的面');
        expect(lands.length, 3 * n, reason: '每次擲都碰地三下（落地＋兩次彈跳）');
      }
    });
  }
}
