/// 呼叫 /api/interpret 並解析 SSE（介面見 docs/API.md）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'settings.dart';

/// 已部署的解籤服務（Vercel）。
const kDeployedApi = 'https://sensorji-draw.vercel.app';

/// 建置時可用 --dart-define-from-file=dart_defines.json 改網址（例如指向測試站）。
const _apiBaseDefine = String.fromEnvironment('API_BASE');

/// 解籤服務網址。Web 預設同網域；App 沒給網址時用已部署的服務，
/// 免得建置時漏了 dart-define 就整個解籤失效（2026-11-28 發生過）。
String get apiBase => _apiBaseDefine.isNotEmpty ? _apiBaseDefine : (kIsWeb ? '' : kDeployedApi);

enum InterpretSection {
  meaning('籤意白話'),
  relation('與你的問題對照'),
  oneLine('給你的一句話'),
  actions('可以做的事'),
  care('我們在這裡');

  const InterpretSection(this.title);
  final String title;

  static InterpretSection? fromWire(String s) => switch (s) {
        'meaning' => meaning,
        'relation' => relation,
        'one_line' => oneLine,
        'actions' => actions,
        'care' => care,
        _ => null,
      };
}

sealed class InterpretEvent {}

class SectionStart extends InterpretEvent {
  SectionStart(this.section);
  final InterpretSection section;
}

class SectionDelta extends InterpretEvent {
  SectionDelta(this.section, this.text);
  final InterpretSection section;
  final String text;
}

class InterpretDone extends InterpretEvent {}

class InterpretError extends InterpretEvent {
  InterpretError(this.message);
  final String message;
}

class InterpretRequest {
  const InterpretRequest({
    required this.deck,
    required this.number,
    required this.categoryId,
    required this.question,
    required this.tone,
  });

  final Deck deck;
  final int number;
  final String categoryId;
  final String question;
  final Tone tone;

  Map<String, Object> toJson() => {
        'deck': deck.name,
        'number': number,
        'category': categoryId,
        'question': question,
        'tone': tone.name,
      };
}

/// 把 SSE 位元組流切成 (event, data) 對。
Stream<(String, Map<String, dynamic>)> parseSse(Stream<String> lines) async* {
  String? event;
  final data = StringBuffer();
  await for (final line in lines) {
    if (line.isEmpty) {
      if (event != null && data.isNotEmpty) {
        yield (event, jsonDecode(data.toString()) as Map<String, dynamic>);
      }
      event = null;
      data.clear();
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.write(line.substring(5).trim());
    }
  }
}

class InterpretClient {
  InterpretClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Stream<InterpretEvent> interpret(InterpretRequest req) async* {
    if (apiBase.isEmpty && !kIsWeb) {
      yield InterpretError('這個版本還沒設定解籤服務的網址');
      return;
    }
    final uri = Uri.parse('$apiBase/api/interpret');
    http.StreamedResponse res;
    try {
      final r = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(req.toJson());
      res = await _client.send(r).timeout(const Duration(seconds: 20));
    } catch (_) {
      yield InterpretError('連不上解籤服務，請檢查網路後再試');
      return;
    }

    if (res.statusCode != 200) {
      var msg = '暫時無法解籤，請稍後再試';
      try {
        final body = jsonDecode(await res.stream.bytesToString()) as Map<String, dynamic>;
        msg = (body['error'] as Map)['message'] as String? ?? msg;
      } catch (_) {}
      yield InterpretError(msg);
      return;
    }

    var finished = false;
    try {
      final lines = res.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final (event, data) in parseSse(lines)) {
        final section = InterpretSection.fromWire(data['section'] as String? ?? '');
        switch (event) {
          case 'start' when section != null:
            yield SectionStart(section);
          case 'delta' when section != null:
            yield SectionDelta(section, data['text'] as String);
          case 'done':
            finished = true;
            yield InterpretDone();
          case 'error':
            finished = true;
            yield InterpretError(data['message'] as String? ?? '暫時無法解籤');
        }
      }
    } catch (_) {
      // 串流中斷，下面統一處理
    }
    if (!finished) yield InterpretError('連線中斷了，請再試一次');
  }
}
