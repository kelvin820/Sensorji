import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../logic/records.dart';
import '../widgets/common.dart';
import '../widgets/season_scaffold.dart';

/// 06 籤詩（淺草寺：正版籤紙）／06b（六十甲子籤：四句直排）。
class PoemScreen extends StatelessWidget {
  const PoemScreen({super.key, required this.readingId});
  final String readingId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final reading = s.records.byId(readingId);
    if (reading == null) return const _Missing();
    final poem = s.poems.poem(reading.deck, reading.number);
    final text = Theme.of(context).textTheme;

    return SeasonScaffold(
      season: reading.season,
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
            child: poem.deck == Deck.sensoji ? _SensojiSlip(poem: poem) : _Tw60Slip(poem: poem),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (poem.deck == Deck.sensoji)
                  Text('雙指可放大細讀', textAlign: TextAlign.center, style: text.bodySmall),
                const SizedBox(height: 8),
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
                const Disclaimer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SensojiSlip extends StatelessWidget {
  const _SensojiSlip({required this.poem});
  final Poem poem;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              image: true,
              label: '第 ${poem.number} 籤 ${poem.rank}：${poem.lines.join('，')}',
              child: DecoratedBox(
                decoration: BoxDecoration(boxShadow: [
                  BoxShadow(color: Palette.ink.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6)),
                ]),
                child: Image.asset(poem.image!, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
}

/// 四句直排，由右至左。
class _Tw60Slip extends StatelessWidget {
  const _Tw60Slip({required this.poem});
  final Poem poem;

  @override
  Widget build(BuildContext context) {
    final style = serif(const TextStyle(fontSize: 26, height: 1.25, color: Palette.ink, fontWeight: FontWeight.w600));
    final text = Theme.of(context).textTheme;
    return Center(
      child: PaperCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('第 ${poem.number} 籤　${poem.ganzhi}', style: text.titleLarge?.copyWith(color: Palette.vermilionDeep)),
            const SizedBox(height: 16),
            Semantics(
              label: poem.lines.join('，'),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    for (final line in poem.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(children: [for (final ch in line.characters) Text(ch, style: style)]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('籤詩參考新港奉天宮版本', style: text.bodySmall?.copyWith(color: Palette.inkSoft)),
          ],
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
              TextButton(onPressed: () => context.go('/'), child: const Text('回首頁')),
            ],
          ),
        ),
      );
}

/// 給其他畫面用。
Reading? readingOf(BuildContext context, String id) => AppScope.of(context).records.byId(id);
