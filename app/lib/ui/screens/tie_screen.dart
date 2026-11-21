import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../logic/records.dart';
import '../widgets/common.dart';
import '../widgets/season_scaffold.dart';

/// 08 凶籤・結籤（僅淺草寺）。靜態版：按下即結籤；之後換成 Rive tie.riv 的拖曳折籤。
class TieScreen extends StatefulWidget {
  const TieScreen({super.key, required this.readingId});
  final String readingId;

  @override
  State<TieScreen> createState() => _TieScreenState();
}

class _TieScreenState extends State<TieScreen> {
  bool _tied = false;

  Future<void> _tie(Reading r) async {
    final s = AppScope.of(context);
    if (s.settings.haptics) {
      HapticFeedback.heavyImpact(); // 一長一短
      Future<void>.delayed(const Duration(milliseconds: 260), HapticFeedback.lightImpact);
    }
    setState(() => _tied = true);
    r.tied = true;
    await s.records.save(r);
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context).records.byId(widget.readingId);
    if (r == null) return const Scaffold(body: Center(child: Text('找不到這次的求籤紀錄')));
    final fg = seasonText(context, r.season);
    final text = Theme.of(context).textTheme;
    final done = _tied || r.tied;

    return SeasonScaffold(
      season: r.season,
      scene: 6,
      particles: false,
      appBar: AppBar(title: const Text('結籤'), foregroundColor: fg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Text(
              done ? '籤已繫在籤架上，\n把不安留在這裡，帶著平靜往前走。' : '在淺草寺，抽到凶籤的人會把籤折起，\n繫在境內的籤架上，祈求轉為吉。',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: fg),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 900),
                child: Image.asset(
                  done ? 'assets/objects/OB07.webp' : 'assets/objects/OB08.webp',
                  key: ValueKey(done),
                  height: done ? 160 : 300,
                ),
              ),
            ),
            if (!done)
              FilledButton(onPressed: () => _tie(r), child: const Text('把籤結上'))
            else ...[
              FilledButton(
                onPressed: () => context.pushReplacement('/interpret/${r.id}'),
                child: const Text('看 AI 解籤'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => context.go('/'), child: const Text('回首頁')),
            ],
            const SizedBox(height: 12),
            Disclaimer(color: fg),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
