import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../logic/draw.dart';
import '../../logic/haptics.dart';
import '../../logic/sounds.dart';
import '../../logic/session.dart';
import '../widgets/jiao_throw.dart';
import '../widgets/season_scaffold.dart';
import 'poem_screen.dart' show kFreshDraw;
import 'number_screen.dart' show saveDrawn;

/// 05 擲筊（僅六十甲子籤）：依設定需 1 次或連續 3 次聖杯，失敗即回搖籤。
/// 筊杯拋起、翻滾、落地彈跳、停定（JiaoThrow），停定後才顯示結果與進度。
class JiaobeiScreen extends StatefulWidget {
  const JiaobeiScreen({super.key, required this.session});
  final DrawSession session;

  @override
  State<JiaobeiScreen> createState() => _JiaobeiScreenState();
}

class _JiaobeiScreenState extends State<JiaobeiScreen> {
  JiaobeiSession? _jiao;
  bool _throwing = false;

  /// 正在擲的這一次結果（動畫停定後才算進 _jiao）。
  JiaoResult? _pending;
  int _throwId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jiao ??= JiaobeiSession(AppScope.of(context).settings.jiaobei.required);
  }

  void _throw() {
    final s = AppScope.of(context);
    setState(() {
      _pending = s.draw.throwJiao();
      _throwing = true;
      _throwId++;
    });
  }

  /// 每次碰地：第一下最重，之後越來越輕。
  void _onLand(int n) {
    // 兩片一起落地的一聲重響，之後彈跳越來越輕
    if (n == 1) {
      Sounds.play(Sfx.jiaoHeavy);
    } else {
      Sounds.play(Sfx.jiaoLight, volume: n == 2 ? 0.9 : 0.5);
    }
    if (!AppScope.of(context).settings.haptics) return;
    Haptics.pulse(n == 1 ? 70 : 35, n == 1 ? 0.9 : 0.45);
  }

  void _onSettled() {
    if (!mounted || !_throwing) return;
    setState(() {
      _jiao!.add(_pending!);
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
              child: JiaoThrow(
                result: _pending,
                throwId: _throwId,
                onLand: _onLand,
                onDone: _onSettled,
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
