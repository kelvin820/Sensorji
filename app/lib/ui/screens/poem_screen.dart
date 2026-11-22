import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../logic/records.dart';
import '../widgets/common.dart';
import '../widgets/lantern.dart';
import '../widgets/season_scaffold.dart';

/// 06 籤詩（淺草寺：正版籤紙）／06b（六十甲子籤：四句直排）。
/// 點籤紙 → 背景調暗，浮出紙卡，四句原文與白話一起顯示（BUILD_PLAN 第 6 節 ⑤）。
/// 淺草寺大吉／吉：右上角降下「成」燈籠，掛在籤紙右上角上方（刻意重疊，籤紙維持原本大小）；
/// 籤紀錄回看時也一樣。
class PoemScreen extends StatelessWidget {
  const PoemScreen({super.key, required this.readingId});
  final String readingId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final reading = s.records.byId(readingId);
    if (reading == null) return const _Missing();
    final poem = s.poems.poem(reading.deck, reading.number);
    final gloss = s.poems.gloss(poem.deck, poem.number);
    final hasGloss = gloss.length == poem.lines.length;
    final text = Theme.of(context).textTheme;
    const fg = Palette.inkSoft; // 籤詩頁一律是和紙底
    final good = poem.isGood;
    final mq = MediaQuery.of(context);

    void openGloss([int? line]) =>
        showGloss(context, poem: poem, gloss: gloss, highlight: line);

    return SeasonScaffold(
      season: reading.season,
      // 用籤詩頁外層的 MediaQuery（Scaffold 內的上方留白已含 AppBar 高度）。
      foreground: good ? MediaQuery(data: mq, child: const GoodLantern()) : null,
      appBar: AppBar(
        title: Text(drawTitle(poem.number, poem.tag)),
        leading: IconButton(
          tooltip: '回首頁',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/'),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: poem.deck == Deck.sensoji
                ? _SensojiSlip(poem: poem, onTap: hasGloss ? openGloss : null)
                : _Tw60Slip(poem: poem, onTapLine: hasGloss ? openGloss : null),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  [
                    if (hasGloss) '點籤詩看白話',
                    if (poem.deck == Deck.sensoji) '雙指可放大細讀',
                  ].join('・'),
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: fg),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => context.push('/interpret/${reading.id}'),
                  child: const Text('請 AI 為我解籤'),
                ),
                if (poem.isBad && !reading.tied) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => context.push('/tie/${reading.id}'),
                    child: const Text('結籤：把籤繫在籤架上'),
                  ),
                ],
                const SizedBox(height: 10),
                const Disclaimer(color: fg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SensojiSlip extends StatelessWidget {
  const _SensojiSlip({required this.poem, this.onTap});
  final Poem poem;
  final VoidCallback? onTap;

  @override
  // 點籤紙區域任何地方都會浮出白話（點擊與雙指縮放不衝突）。
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(
            image: true,
            button: onTap != null,
            label: '第 ${poem.number} 籤 ${poem.rank}：${poem.lines.join('，')}',
            hint: onTap != null ? '點兩下看白話' : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Palette.ink.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Image.asset(poem.image!, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 四句直排，由右至左。點任一句 → 浮出白話，並標出點的那一句。
class _Tw60Slip extends StatelessWidget {
  const _Tw60Slip({required this.poem, this.onTapLine});
  final Poem poem;
  final ValueChanged<int>? onTapLine;

  @override
  Widget build(BuildContext context) {
    final style = brush(
      const TextStyle(fontSize: 30, height: 1.2, color: Palette.ink),
    );
    final text = Theme.of(context).textTheme;
    return Center(
      child: PaperCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '第 ${poem.number} 籤　${poem.ganzhi}',
              style: text.titleLarge?.copyWith(color: Palette.vermilionDeep),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: poem.lines.join('，'),
              button: onTapLine != null,
              hint: onTapLine != null ? '點兩下看白話' : null,
              onTap: onTapLine == null ? null : () => onTapLine!(0),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    for (final (i, line) in poem.lines.indexed)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onTapLine == null ? null : () => onTapLine!(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              for (final ch in line.characters)
                                Text(ch, style: style),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '籤詩參考新港奉天宮版本',
              style: text.bodySmall?.copyWith(color: Palette.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// 浮出逐句白話：背景調暗、紙卡由下往上淡入，四句原文（毛筆字）與白話並列。
/// [highlight] 是使用者點的那一句（六十甲子籤），會用朱紅框標出。
Future<void> showGloss(
  BuildContext context, {
  required Poem poem,
  required List<String> gloss,
  int? highlight,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '收起白話',
    barrierColor: Palette.ink.withValues(alpha: 0.55),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320),
    pageBuilder: (context, _, _) =>
        _GlossCard(poem: poem, gloss: gloss, highlight: highlight),
    transitionBuilder: (context, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(a),
          child: child,
        ),
      );
    },
  );
}

class _GlossCard extends StatelessWidget {
  const _GlossCard({required this.poem, required this.gloss, this.highlight});
  final Poem poem;
  final List<String> gloss;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = poem.deck == Deck.sensoji
        ? '第 ${poem.number} 籤・${poem.rank}'
        : '第 ${poem.number} 籤・${poem.ganzhi}';
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              color: Palette.card,
              elevation: 12,
              shadowColor: Palette.ink.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Palette.line),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: text.titleLarge?.copyWith(
                        color: Palette.vermilionDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '逐句白話',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: Palette.inkSoft),
                    ),
                    const SizedBox(height: 12),
                    for (final (i, line) in poem.lines.indexed)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        decoration: BoxDecoration(
                          color: i == highlight
                              ? const Color(0xFFF7E3DA)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: i == highlight
                                ? Palette.vermilion
                                : Palette.line,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line,
                              style: brush(
                                const TextStyle(
                                  fontSize: 24,
                                  color: Palette.ink,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gloss[i],
                              style: text.bodyMedium?.copyWith(
                                color: Palette.ink,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Palette.inkSoft,
                        minimumSize: const Size(44, 48),
                      ),
                      child: const Text('收起'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('找不到這次的求籤紀錄'),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('回首頁'),
          ),
        ],
      ),
    ),
  );
}

/// 給其他畫面用。
Reading? readingOf(BuildContext context, String id) =>
    AppScope.of(context).records.byId(id);
