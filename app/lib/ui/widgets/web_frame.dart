import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// 網頁版在寬螢幕（桌機、平板橫放）上：App 放在置中的直式手機框裡，不拉成整面寬。
/// 框內的 MediaQuery 改成框的大小，所有畫面照手機版排；對話框、底部面板也留在框內。
/// 寬螢幕左側放一小段介紹（[showAside]）。窄螢幕（手機）直接全螢幕，不加框。
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});
  final Widget child;

  static const phoneWidth = 430.0;
  static const maxHeight = 920.0;

  /// 比這個窄就當手機，全螢幕顯示。
  static const minFramedWidth = 640.0;

  static bool framed(Size s) => s.width >= minFramedWidth;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    if (!framed(size)) return child;
    final h = size.height < 720
        ? size.height
        : min(size.height - 48, maxHeight);
    final rounded = h < size.height;
    final showAside = size.width >= 1000;

    final phone = Container(
      width: phoneWidth,
      height: h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(rounded ? 28 : 0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: MediaQuery(
        data: mq.copyWith(
          size: Size(phoneWidth, h),
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
        ),
        child: child,
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241B16), Color(0xFF3A1A12), Color(0xFF1B1613)],
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAside) ...[const _Aside(), const SizedBox(width: 72)],
            phone,
          ],
        ),
      ),
    );
  }
}

class _Aside extends StatelessWidget {
  const _Aside();

  @override
  Widget build(BuildContext context) {
    const soft = Palette.nightTextSoft;
    // 框外沒有 Material，要自己給文字樣式（不然會出現除錯用的黃色底線）
    return ExcludeSemantics(
      child: DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          fontWeight: FontWeight.normal,
        ),
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/brand/icon_1024.png', width: 88, height: 88),
              const SizedBox(height: 20),
              const Text(
                '心想事',
                style: TextStyle(
                  fontFamily: brushFamily,
                  fontSize: 56,
                  color: Palette.nightText,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '心裡想著一件事，求一支籤，\n聽聽它怎麼說。',
                style: TextStyle(
                  fontSize: 18,
                  color: Palette.nightText,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Icon(Icons.phone_iphone, size: 18, color: soft),
                  const SizedBox(width: 8),
                  Text(
                    '用手機開啟，可以真的搖籤筒',
                    style: TextStyle(
                      fontSize: 14,
                      color: soft.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.keyboard, size: 18, color: soft),
                  SizedBox(width: 8),
                  Text(
                    '電腦上點籤筒或按空白鍵搖籤',
                    style: TextStyle(fontSize: 14, color: soft),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
