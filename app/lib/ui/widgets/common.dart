import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// 介面必備提示（BUILD_PLAN 第 0 節）。
class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        '籤詩僅供參考與慰藉',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color ?? DefaultTextStyle.of(context).style.color?.withValues(alpha: 0.85),
              letterSpacing: 2,
            ),
      );
}

/// 墨字標誌（冬夜用淺色版）。
class Logo extends StatelessWidget {
  const Logo({super.key, this.width = 220, this.light = false});
  final double width;
  final bool light;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '心想事',
        image: true,
        child: Image.asset(
          light ? 'assets/brand/logo_light.png' : 'assets/brand/logo_ink.png',
          width: width,
        ),
      );
}

/// 米白卡片。
class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Palette.ink),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// 籤號＋吉凶／干支的標題，例：第 28 籤・凶。
String drawTitle(int number, String tag) => '第 $number 籤・$tag';
