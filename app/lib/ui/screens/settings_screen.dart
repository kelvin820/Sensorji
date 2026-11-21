import 'package:material_ui/material_ui.dart';

import '../../app/scope.dart';
import '../../data/models.dart';
import '../../logic/draw.dart';
import '../../logic/season.dart';
import '../../logic/settings.dart';
import '../../logic/shake.dart';
import '../widgets/common.dart';
import '../widgets/season_scaffold.dart';

/// 10 設定。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = s.settings;
    return SeasonScaffold(
      season: st.currentSeason(),
      appBar: AppBar(title: const Text('設定')),
      child: ListenableBuilder(
        listenable: st,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Group('求籤', [
              _choice<Deck>(context, '預設籤種', Deck.values, st.defaultDeck, (v) => v.label, (v) => st.defaultDeck = v),
              _choice<JiaobeiMode>(context, '擲筊確認（六十甲子籤）', JiaobeiMode.values, st.jiaobei, (v) => v.label,
                  (v) => st.jiaobei = v),
              _choice<ShakeSensitivity>(context, '搖晃靈敏度', ShakeSensitivity.values, st.sensitivity, (v) => v.label,
                  (v) => st.sensitivity = v),
              SwitchListTile(
                title: const Text('震動回饋'),
                value: st.haptics,
                onChanged: (v) => st.haptics = v,
              ),
            ]),
            _Group('解說', [
              _choice<Tone>(context, '解說語氣', Tone.values, st.tone, (v) => v.label, (v) => st.tone = v),
            ]),
            _Group('季節', [
              _choice<SeasonMode>(context, '季節', SeasonMode.values, st.seasonMode, (v) => v.label,
                  (v) => st.seasonMode = v),
              if (st.seasonMode == SeasonMode.fixed)
                _choice<Season>(
                  context,
                  '固定為',
                  const [Season.spring, Season.summer, Season.autumn, Season.winter],
                  st.fixedSeason == Season.summerNoon ? Season.summer : st.fixedSeason,
                  (v) => v.isSummer ? '夏' : v.label,
                  (v) => st.fixedSeason = v,
                ),
              ListTile(title: const Text('現在顯示'), trailing: Text(st.currentSeason().label)),
            ]),
            _Group('紀錄', [
              ListTile(
                title: const Text('清除所有紀錄'),
                textColor: Theme.of(context).colorScheme.primary,
                onTap: () => _confirmClear(context),
              ),
            ]),
            const SizedBox(height: 16),
            const Disclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _choice<T>(
    BuildContext context,
    String title,
    List<T> values,
    T current,
    String Function(T) label,
    void Function(T) onChanged,
  ) =>
      ListTile(
        title: Text(title),
        trailing: DropdownButton<T>(
          value: current,
          underline: const SizedBox.shrink(),
          items: [for (final v in values) DropdownMenuItem(value: v, child: Text(label(v)))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );

  /// 二次確認（BUILD_PLAN 第 9 節）。
  Future<void> _confirmClear(BuildContext context) async {
    final records = AppScope.of(context).records;
    final first = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清除所有紀錄？'),
        content: const Text('所有求籤紀錄與 AI 解說都會刪除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('繼續')),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('真的要清除嗎？'),
        content: const Text('清除後無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('清除')),
        ],
      ),
    );
    if (second == true) {
      await records.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除所有紀錄')));
      }
    }
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            PaperCard(padding: EdgeInsets.zero, child: Column(children: children)),
          ],
        ),
      );
}
