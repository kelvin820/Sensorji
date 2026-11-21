import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../logic/season.dart';
import 'particles.dart';

/// 有季節背景的畫面骨架：背景圖 → 漸層 → 粒子 → 內容。
/// [scene] 為背景編號 1–6；傳 null 則改用和紙紋理（06 籤詩、09 紀錄、10 設定）。
class SeasonScaffold extends StatelessWidget {
  const SeasonScaffold({
    super.key,
    required this.season,
    required this.child,
    this.scene,
    this.noLantern = false,
    this.particles = true,
    this.smoke = false,
    this.overlay = true,
    this.appBar,
  });

  final Season season;
  final int? scene;
  final bool noLantern;
  final bool particles;
  final bool smoke;
  final bool overlay;
  final PreferredSizeWidget? appBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = scene == null ? SeasonLook.day : SeasonLook.of(season);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (scene != null)
            Image.asset(
              season.background(scene!, noLantern: noLantern),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stack) =>
                  Image.asset(Season.autumn.background(scene!, noLantern: noLantern), fit: BoxFit.cover),
            )
          else
            const _PaperTexture(),
          if (scene != null && overlay)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: look.overlay,
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          if (particles && !reduced && scene != null)
            IgnorePointer(child: ParticleLayer(sprites: season.particles)),
          if (smoke && !reduced) const IgnorePointer(child: SmokeLayer()),
          DefaultTextStyle.merge(
            style: TextStyle(color: look.text),
            child: IconTheme.merge(
              data: IconThemeData(color: look.text),
              child: SafeArea(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperTexture extends StatelessWidget {
  const _PaperTexture();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.paper,
          image: DecorationImage(
            image: AssetImage('assets/textures/TX01.webp'),
            repeat: ImageRepeat.repeat,
            scale: 2,
          ),
        ),
      );
}

/// 畫面上的文字色（冬夜時為淺色）。
Color seasonText(BuildContext context, Season s, {bool soft = false}) {
  final look = SeasonLook.of(s);
  return soft ? look.textSoft : look.text;
}
