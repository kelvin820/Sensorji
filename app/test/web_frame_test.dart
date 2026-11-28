import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/app/theme.dart';
import 'package:sensoji/ui/widgets/web_frame.dart';

void main() {
  setUp(() => useGoogleFonts = false);

  Future<Size> innerSize(WidgetTester tester, Size window) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Size seen;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => WebFrame(child: child!),
      home: Builder(builder: (context) {
        seen = MediaQuery.sizeOf(context);
        return const Text('app');
      }),
    ));
    return seen;
  }

  testWidgets('手機寬度：全螢幕、不加框', (tester) async {
    expect(await innerSize(tester, const Size(390, 844)), const Size(390, 844));
  });

  testWidgets('桌機：App 放進 430 寬的直式框，框內 MediaQuery 是框的大小', (tester) async {
    final s = await innerSize(tester, const Size(1440, 900));
    expect(s.width, WebFrame.phoneWidth);
    expect(s.height, 900 - 48);
    expect(find.text('心想事'), findsOneWidget, reason: '寬螢幕左側有介紹');
    expect(tester.getSize(find.text('app')).width, lessThanOrEqualTo(WebFrame.phoneWidth));
  });

  testWidgets('平板寬度：有框但沒有側邊介紹；很矮的視窗不留上下邊', (tester) async {
    final s = await innerSize(tester, const Size(800, 640));
    expect(s, const Size(WebFrame.phoneWidth, 640));
    expect(find.text('心想事'), findsNothing);
  });
}
