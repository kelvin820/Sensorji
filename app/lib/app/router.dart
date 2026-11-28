import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../logic/session.dart';
import '../ui/screens/ask_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/interpret_screen.dart';
import '../ui/screens/jiaobei_screen.dart';
import '../ui/screens/number_screen.dart';
import '../ui/screens/poem_screen.dart';
import '../ui/screens/privacy_screen.dart';
import '../ui/screens/records_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/shake_screen.dart';
import '../ui/screens/tie_screen.dart';

/// 路由（BUILD_PLAN 第 3 節）：首頁 → 提問 → 搖籤 → 籤號 →（擲筊）→ 籤詩 → AI 解籤；
/// 分支：結籤、紀錄、設定。搖籤到擲筊之間的狀態放在 DrawSession（extra），
/// 籤詩之後以紀錄 id 定位，所以重新整理（Web）或從紀錄進入都能重看。
/// 搖籤頁 → 籤號頁的淡入長度。
const kNumberFadeIn = Duration(milliseconds: 1100);

GoRouter buildRouter() {
  Widget withSession(GoRouterState state, Widget Function(DrawSession) build) {
    final s = state.extra;
    return s is DrawSession ? build(s) : const HomeScreen();
  }

  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/ask', builder: (_, _) => const AskScreen()),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: '/shake', builder: (_, s) => withSession(s, (x) => ShakeScreen(session: x))),
      // 籤號落出後慢慢淡入籤櫃（使用者回饋：落籤的畫面太快換掉）。
      GoRoute(
        path: '/number',
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          transitionDuration: kNumberFadeIn,
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut), child: child),
          child: withSession(s, (x) => NumberScreen(session: x)),
        ),
      ),
      GoRoute(path: '/jiaobei', builder: (_, s) => withSession(s, (x) => JiaobeiScreen(session: x))),
      // extra 為 kFreshDraw：剛抽到，播籤紙展開（分鏡 ④）；從紀錄回看或重新整理則直接攤平。
      GoRoute(
        path: '/poem/:id',
        builder: (_, s) => PoemScreen(readingId: s.pathParameters['id']!, fresh: s.extra == kFreshDraw),
      ),
      GoRoute(path: '/interpret/:id', builder: (_, s) => InterpretScreen(readingId: s.pathParameters['id']!)),
      GoRoute(path: '/tie/:id', builder: (_, s) => TieScreen(readingId: s.pathParameters['id']!)),
      GoRoute(path: '/records', builder: (_, _) => const RecordsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
}
