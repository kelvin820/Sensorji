import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../logic/haptics.dart';
import '../../logic/records.dart';
import '../widgets/common.dart';
import '../widgets/season_scaffold.dart';
import '../widgets/tie_fold.dart';

/// 08 凶籤・結籤（僅淺草寺，分鏡 ⑥）：往左拖把籤紙折成細條 → 繫上籤架、繩結收緊 → 畫面微暗。
class TieScreen extends StatefulWidget {
  const TieScreen({super.key, required this.readingId});
  final String readingId;

  @override
  State<TieScreen> createState() => _TieScreenState();
}

class _TieScreenState extends State<TieScreen> {
  final _fold = GlobalKey<TieFoldState>();
  bool _done = false;

  bool get _haptics => AppScope.of(context).settings.haptics;

  /// 繩結收緊：存成已結籤，一長一短震動。
  Future<void> _knot(Reading r) async {
    if (_haptics) {
      Haptics.pulse(220, 1);
      Future<void>.delayed(const Duration(milliseconds: 380), () => Haptics.pulse(60, 0.6));
    }
    r.tied = true;
    await AppScope.of(context).records.save(r);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = s.records.byId(widget.readingId);
    if (r == null) return const Scaffold(body: Center(child: Text('找不到這次的求籤紀錄')));
    final poem = s.poems.poem(r.deck, r.number);
    final fg = seasonText(context, r.season);
    final text = Theme.of(context).textTheme;
    final done = _done || r.tied;
    final fade = Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 500);

    return SeasonScaffold(
      season: r.season,
      scene: 6,
      particles: false,
      appBar: AppBar(title: const Text('結籤'), foregroundColor: fg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: fade,
              child: Text(
                done
                    ? '籤已繫在籤架上，\n把不安留在這裡，帶著平靜往前走。'
                    : '在淺草寺，抽到凶籤的人會把籤折起，\n繫在境內的籤架上，祈求轉為吉。',
                key: ValueKey(done),
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: fg),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TieFold(
                  key: _fold,
                  slipImage: poem.image!,
                  tied: r.tied,
                  onFoldStep: (_) {
                    if (_haptics) Haptics.pulse(25, 0.35); // 每折一折
                  },
                  onKnot: () => _knot(r),
                  onDone: () {
                    if (mounted) setState(() => _done = true);
                  },
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: fade,
              child: done
                  ? Column(
                      key: const ValueKey('done'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () => context.pushReplacement('/interpret/${r.id}'),
                          child: const Text('看 AI 解籤'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(onPressed: () => context.go('/'), child: const Text('回首頁')),
                      ],
                    )
                  : Column(
                      key: const ValueKey('fold'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '用手指把籤紙往左拖，折成細條',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: fg),
                        ),
                        const SizedBox(height: 8),
                        // 不方便拖曳（或用讀屏）時用這顆
                        OutlinedButton(
                          onPressed: () => _fold.currentState?.foldAll(),
                          child: const Text('幫我折好、結上'),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Disclaimer(color: fg),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
