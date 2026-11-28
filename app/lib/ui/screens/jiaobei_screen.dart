import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../logic/draw.dart';
import '../../logic/session.dart';
import '../widgets/season_scaffold.dart';
import 'poem_screen.dart' show kFreshDraw;
import 'number_screen.dart' show saveDrawn;

/// 05 擲筊（僅六十甲子籤）：依設定需 1 次或連續 3 次聖杯，失敗即回搖籤。
/// 之後筊杯換成 Rive jiaobei.riv。
class JiaobeiScreen extends StatefulWidget {
  const JiaobeiScreen({super.key, required this.session});
  final DrawSession session;

  @override
  State<JiaobeiScreen> createState() => _JiaobeiScreenState();
}

class _JiaobeiScreenState extends State<JiaobeiScreen> {
  JiaobeiSession? _jiao;
  bool _throwing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jiao ??= JiaobeiSession(AppScope.of(context).settings.jiaobei.required);
  }

  Future<void> _throw() async {
    final s = AppScope.of(context);
    setState(() => _throwing = true);
    if (!MediaQuery.disableAnimationsOf(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    final r = s.draw.throwJiao();
    if (s.settings.haptics) HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _jiao!.add(r);
      _throwing = false;
    });
  }

  Future<void> _continue() async {
    final session = widget.session;
    final jiao = _jiao!;
    if (jiao.status == JiaobeiStatus.confirmed) {
      final id = await saveDrawn(context, session);
      if (mounted) context.pushReplacement('/poem/$id', extra: kFreshDraw);
    } else {
      session
        ..attempt += 1
        ..number = null;
      context.pushReplacement('/shake', extra: session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final jiao = _jiao!;
    final fg = seasonText(context, session.season);
    final text = Theme.of(context).textTheme;
    final last = jiao.results.isEmpty ? null : jiao.results.last;
    final done = jiao.status != JiaobeiStatus.inProgress;

    return SeasonScaffold(
      season: session.season,
      scene: 4,
      particles: false,
      appBar: AppBar(title: Text('第 ${session.number} 籤・擲筊確認'), foregroundColor: fg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Text(
              jiao.required == 1 ? '擲出一個聖杯，即確認是這支籤' : '連續擲出三個聖杯，即確認是這支籤',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: fg),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: '聖杯 ${jiao.holyCount} / ${jiao.required}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < jiao.required; i++)
                    Container(
                      margin: const EdgeInsets.all(6),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < jiao.holyCount ? Palette.vermilion : Palette.card,
                        border: Border.all(color: Palette.inkSoft),
                      ),
                      child: Text('聖', style: TextStyle(color: i < jiao.holyCount ? Colors.white : Palette.inkSoft)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _throwing
                      ? Image.asset('assets/objects/OB05_single.webp', key: const ValueKey('air'), height: 160)
                      : last == null
                          ? Image.asset('assets/objects/OB05.webp', key: const ValueKey('idle'), height: 180)
                          : _JiaoPair(result: last, key: ValueKey(jiao.results.length)),
                ),
              ),
            ),
            if (last != null && !_throwing) ...[
              Text(last.label, style: text.headlineMedium?.copyWith(color: fg)),
              Text(last.meaning, style: text.bodyMedium?.copyWith(color: fg)),
              const SizedBox(height: 8),
            ],
            if (done)
              Text(
                jiao.status == JiaobeiStatus.confirmed ? '神明應允，請看籤詩' : '不是這支籤，請重新搖籤',
                style: text.titleMedium?.copyWith(color: fg),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _throwing ? null : (done ? _continue : _throw),
                child: Text(done
                    ? (jiao.status == JiaobeiStatus.confirmed ? '看籤詩' : '重新搖籤')
                    : '擲筊'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _JiaoPair extends StatelessWidget {
  const _JiaoPair({super.key, required this.result});
  final JiaoResult result;

  @override
  Widget build(BuildContext context) {
    final (a, b) = switch (result) {
      JiaoResult.holy => ('OB05_flat', 'OB05_round'),
      JiaoResult.laughing => ('OB05_flat', 'OB05_flat'),
      JiaoResult.negative => ('OB05_round', 'OB05_round'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/objects/$a.webp', height: 110),
        const SizedBox(width: 12),
        Transform.flip(flipX: true, child: Image.asset('assets/objects/$b.webp', height: 110)),
      ],
    );
  }
}
