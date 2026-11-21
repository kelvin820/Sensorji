import 'package:flutter/widgets.dart';

import '../data/repository.dart';
import '../logic/draw.dart';
import '../logic/interpret_client.dart';
import '../logic/records.dart';
import '../logic/settings.dart';

/// App 全域服務。用 AppScope.of(context) 取得。
class AppServices {
  AppServices({
    required this.poems,
    required this.settings,
    required this.records,
    DrawService? draw,
    InterpretClient? interpreter,
  })  : draw = draw ?? DrawService(),
        interpreter = interpreter ?? InterpretClient();

  final PoemRepository poems;
  final Settings settings;
  final RecordStore records;
  final DrawService draw;
  final InterpretClient interpreter;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
