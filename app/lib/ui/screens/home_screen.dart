import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../widgets/common.dart';
import '../widgets/lantern.dart';
import '../widgets/season_scaffold.dart';
import '../widgets/summer_decor.dart';

/// 01 首頁：雷門大燈籠、開始求籤、紀錄、設定。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.settings,
      builder: (context, _) {
        final season = s.settings.currentSeason();
        // 換季時交叉淡化 1.5 秒
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 1500),
          child: SeasonScaffold(
            key: ValueKey(season),
            season: season,
            scene: 1,
            noLantern: true,
            smoke: true,
            decor: season.isSummer ? const _EaveChime() : null,
            child: LayoutBuilder(
              builder: (context, box) => Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: '設定',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => context.push('/settings'),
                    ),
                  ),
                  SizedBox(height: box.maxHeight * 0.42, child: const _Lantern()),
                  const Spacer(),
                  Logo(width: 200, light: season.isNight),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () => context.push('/ask'),
                          child: const Text('開始求籤'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => context.push('/records'),
                          child: const Text('我的籤紀錄'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Disclaimer(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 雷門大燈籠：OB01_raimon（「雷門」已合成在圖上，App 不疊字），繞頂環中央緩慢擺動。
class _Lantern extends StatefulWidget {
  const _Lantern();

  @override
  State<_Lantern> createState() => _LanternState();
}

class _LanternState extends State<_Lantern> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight * 0.92;
        final rope = box.maxHeight * 0.08;
        Widget lantern = Image.asset(
          'assets/objects/OB01_raimon.webp',
          height: h,
          width: h / kLanternAspect,
          semanticLabel: '雷門大燈籠',
        );
        if (!reduced) {
          lantern = AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.rotate(
              angle: sin(_c.value * 2 * pi) * 0.035,
              alignment: kLanternPivot, // 頂環中央
              child: child,
            ),
            child: lantern,
          );
        }
        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // 吊繩：從上方垂到頂環中央（圖頂有透明邊，要多畫一段才接得上）。
            Container(width: 3, height: rope + h * kLanternPivotY, color: Palette.ink),
            Padding(padding: EdgeInsets.only(top: rope), child: lantern),
          ],
        );
      },
    );
  }
}

/// 夏季：簷下掛一只風鈴，從畫面頂端垂下。
class _EaveChime extends StatelessWidget {
  const _EaveChime();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: 0,
      left: 28,
      child: WindChime(height: mq.size.height * 0.2, rope: mq.padding.top + 24),
    );
  }
}
