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

/// 問題輸入框：整塊和紙卡片，標題與字數都在卡片裡，
/// 放在任何季節背景（包括冬夜深色背景）上都看得清楚，標題也不會壓在框線上。
class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.controller,
    required this.maxLength,
    this.label,
    this.hint,
    this.minLines = 2,
    this.maxLines = 4,
  });

  final TextEditingController controller;
  final int maxLength;
  final String? label;
  final String? hint;
  final int minLines;
  final int maxLines;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? Palette.vermilion : Palette.line,
          width: focused ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.label != null)
                Expanded(
                  child: Text(
                    widget.label!,
                    style: text.labelLarge?.copyWith(
                      color: focused ? Palette.vermilionDeep : Palette.inkSoft,
                    ),
                  ),
                )
              else
                const Spacer(),
              ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => Text(
                  '${widget.controller.text.characters.length}/${widget.maxLength}',
                  style: text.bodySmall?.copyWith(color: Palette.inkSoft),
                ),
              ),
            ],
          ),
          TextField(
            controller: widget.controller,
            focusNode: _focus,
            maxLength: widget.maxLength,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            style: text.bodyLarge?.copyWith(color: Palette.ink, height: 1.5),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: Palette.inkSoft.withValues(alpha: 0.8)),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              counterText: '', // 字數改顯示在標題列
            ),
          ),
        ],
      ),
    );
  }
}
