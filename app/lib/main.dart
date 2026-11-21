import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'app/scope.dart';
import 'app/theme.dart';
import 'data/repository.dart';
import 'logic/records.dart';
import 'logic/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = AppServices(
    poems: await PoemRepository.load(),
    settings: await Settings.load(),
    records: await RecordStore.load(),
  );
  runApp(SensojiApp(services: services));
}

class SensojiApp extends StatefulWidget {
  const SensojiApp({super.key, required this.services, this.router});
  final AppServices services;
  final GoRouter? router;

  @override
  State<SensojiApp> createState() => _SensojiAppState();
}

class _SensojiAppState extends State<SensojiApp> {
  late final GoRouter _router = widget.router ?? buildRouter();
  late final ThemeData _theme = buildTheme();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp.router(
        title: '心想事',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        locale: const Locale('zh', 'TW'),
        routerConfig: _router,
      ),
    );
  }
}
