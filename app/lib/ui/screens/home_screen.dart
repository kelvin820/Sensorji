import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../widgets/common.dart';
import '../widgets/season_scaffold.dart';

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

/// 雷門大燈籠：靜態 PNG 緩慢擺動，「雷門」由 App 疊字。之後換成 Rive lantern.riv。
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
    final lantern = LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight * 0.92;
        return Column(
          children: [
            Container(width: 3, height: box.maxHeight * 0.08, color: Palette.ink), // 吊繩
            SizedBox(
              height: h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset('assets/objects/OB01.webp', height: h),
                  Text(
                    '雷門',
                    style: serif(TextStyle(
                      fontSize: h * 0.2,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1B1410),
                      height: 1,
                    )),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (reduced) return lantern;
    return AnimatedBuilder(
      animation: _c,
      // 旋轉中心在頂端吊繩處
      builder: (context, child) => Transform.rotate(
        angle: sin(_c.value * 2 * pi) * 0.035,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: lantern,
    );
  }
}
