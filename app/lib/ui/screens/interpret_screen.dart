import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../logic/interpret_client.dart';
import '../../logic/records.dart';
import '../widgets/common.dart';
import '../widgets/season_scaffold.dart';

/// 07 AI 解籤。紀錄裡已有解說就直接顯示（09 紀錄重看），沒有就向後端要。
class InterpretScreen extends StatefulWidget {
  const InterpretScreen({super.key, required this.readingId});
  final String readingId;

  @override
  State<InterpretScreen> createState() => _InterpretScreenState();
}

class _InterpretScreenState extends State<InterpretScreen> {
  Reading? _reading;
  final Map<InterpretSection, String> _sections = {};
  StreamSubscription<InterpretEvent>? _sub;
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reading != null) return;
    _reading = AppScope.of(context).records.byId(widget.readingId);
    final r = _reading;
    if (r == null) return;
    if (r.sections.isEmpty) {
      _start();
    } else {
      for (final e in r.sections.entries) {
        final sec = InterpretSection.values.where((v) => v.name == e.key).firstOrNull;
        if (sec != null) _sections[sec] = e.value;
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    final s = AppScope.of(context);
    final r = _reading!;
    setState(() {
      _sections.clear();
      _error = null;
      _loading = true;
    });
    _sub?.cancel();
    _sub = s.interpreter
        .interpret(InterpretRequest(
          deck: r.deck,
          number: r.number,
          categoryId: r.categoryId,
          question: r.question,
          tone: s.settings.tone,
        ))
        .listen((e) {
      switch (e) {
        case SectionStart(:final section):
          setState(() => _sections[section] = '');
        case SectionDelta(:final section, :final text):
          setState(() => _sections[section] = (_sections[section] ?? '') + text);
        case InterpretDone():
          _save();
          setState(() => _loading = false);
        case InterpretError(:final message):
          setState(() {
            _error = message;
            _loading = false;
          });
      }
    });
  }

  Future<void> _save() async {
    final r = _reading!;
    r.sections
      ..clear()
      ..addAll({for (final e in _sections.entries) e.key.name: e.value.trim()});
    await AppScope.of(context).records.save(r);
  }

  Future<void> _toggleFavorite() async {
    final r = _reading!;
    setState(() => r.favorite = !r.favorite);
    await AppScope.of(context).records.save(r);
  }

  void _share() {
    final r = _reading!;
    final buf = StringBuffer('心想事・${drawTitle(r.number, r.tag)}\n');
    for (final sec in InterpretSection.values) {
      final t = _sections[sec];
      if (t != null && t.isNotEmpty) buf.write('\n【${sec.title}】\n${t.trim()}\n');
    }
    buf.write('\n籤詩僅供參考與慰藉');
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製，可以貼給朋友')));
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    if (r == null) {
      return Scaffold(body: Center(child: TextButton(onPressed: () => context.go('/'), child: const Text('回首頁'))));
    }
    final s = AppScope.of(context);
    final fg = seasonText(context, r.season);
    final text = Theme.of(context).textTheme;
    final care = _sections.containsKey(InterpretSection.care);
    final category = s.poems.category(r.categoryId);

    return SeasonScaffold(
      season: r.season,
      scene: 5,
      particles: false,
      appBar: AppBar(
        title: Text(drawTitle(r.number, r.tag)),
        foregroundColor: fg,
        actions: [
          IconButton(
            tooltip: r.favorite ? '取消收藏' : '收藏',
            icon: Icon(r.favorite ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('你的問題・${category.label}', style: text.titleMedium?.copyWith(color: Palette.inkSoft)),
                const SizedBox(height: 6),
                Text(r.question.isEmpty ? '（未輸入問題）' : r.question, style: text.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final sec in InterpretSection.values)
            if (_sections.containsKey(sec)) ...[
              _SectionCard(section: sec, text: _sections[sec]!),
              const SizedBox(height: 14),
            ],
          if (_loading && _sections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(color: fg),
                  const SizedBox(height: 12),
                  Text('正在為你解籤…', style: text.bodyMedium?.copyWith(color: fg)),
                ],
              ),
            ),
          if (_error != null)
            PaperCard(
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _start, child: const Text('再試一次')),
                ],
              ),
            ),
          if (!_loading && _error == null) ...[
            Text(
              care ? '你不必一個人面對。' : '籤詩僅供參考與慰藉。解說由 AI 產生，不代表預言，重要決定請和信任的人或專業人士討論。',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: fg),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => context.go('/ask'), child: const Text('再問一件事')),
                ),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton(onPressed: _share, child: const Text('分享'))),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => context.go('/'), child: const Text('回首頁')),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.text});
  final InterpretSection section;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final body = text.trim();
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: t.titleMedium?.copyWith(color: Palette.vermilionDeep)),
          const SizedBox(height: 8),
          if (section == InterpretSection.oneLine)
            Text(body, style: serif(t.titleLarge!.copyWith(color: Palette.gold, height: 1.5)))
          else if (section == InterpretSection.actions)
            for (final line in body.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('・', style: TextStyle(color: Palette.vermilion)),
                    Expanded(child: Text(line.replaceFirst(RegExp(r'^[-・•]\s*'), ''), style: t.bodyLarge)),
                  ],
                ),
              )
          else
            Text(body, style: t.bodyLarge),
        ],
      ),
    );
  }
}
