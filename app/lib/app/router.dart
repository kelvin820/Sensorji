import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../logic/session.dart';
import '../ui/screens/ask_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/interpret_screen.dart';
import '../ui/screens/jiaobei_screen.dart';
import '../ui/screens/number_screen.dart';
import '../ui/screens/poem_screen.dart';
import '../ui/screens/records_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/shake_screen.dart';
import '../ui/screens/tie_screen.dart';

/// 路由（BUILD_PLAN 第 3 節）：首頁 → 提問 → 搖籤 → 籤號 →（擲筊）→ 籤詩 → AI 解籤；
/// 分支：結籤、紀錄、設定。搖籤到擲筊之間的狀態放在 DrawSession（extra），
/// 籤詩之後以紀錄 id 定位，所以重新整理（Web）或從紀錄進入都能重看。
GoRouter buildRouter() {
  Widget withSession(GoRouterState state, Widget Function(DrawSession) build) {
    final s = state.extra;
    return s is DrawSession ? build(s) : const HomeScreen();
  }

  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/ask', builder: (_, _) => const AskScreen()),
      GoRoute(path: '/shake', builder: (_, s) => withSession(s, (x) => ShakeScreen(session: x))),
      GoRoute(path: '/number', builder: (_, s) => withSession(s, (x) => NumberScreen(session: x))),
      GoRoute(path: '/jiaobei', builder: (_, s) => withSession(s, (x) => JiaobeiScreen(session: x))),
      GoRoute(path: '/poem/:id', builder: (_, s) => PoemScreen(readingId: s.pathParameters['id']!)),
      GoRoute(path: '/interpret/:id', builder: (_, s) => InterpretScreen(readingId: s.pathParameters['id']!)),
      GoRoute(path: '/tie/:id', builder: (_, s) => TieScreen(readingId: s.pathParameters['id']!)),
      GoRoute(path: '/records', builder: (_, _) => const RecordsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
}
