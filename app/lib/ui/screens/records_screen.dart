import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../logic/records.dart';
import '../widgets/common.dart';
import '../widgets/season_scaffold.dart';

/// 09 我的籤紀錄：全部／已收藏／依類別。
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String _filter = 'all'; // all | fav | 類別 id

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    return SeasonScaffold(
      season: s.settings.currentSeason(),
      appBar: AppBar(title: const Text('我的籤紀錄')),
      child: ListenableBuilder(
        listenable: s.records,
        builder: (context, _) {
          final items = s.records.all.where((r) => switch (_filter) {
                'all' => true,
                'fav' => r.favorite,
                final id => r.categoryId == id,
              }).toList();
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _chip('全部', 'all'),
                    _chip('已收藏', 'fav'),
                    for (final c in s.poems.categories) _chip(c.label, c.id),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('還沒有紀錄', style: text.bodyLarge))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _RecordTile(reading: items[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.reading});
  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = reading;
    final text = Theme.of(context).textTheme;
    final t = r.time;
    final date = '${t.year}/${t.month}/${t.day}';
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Palette.vermilion, borderRadius: BorderRadius.circular(14)),
        child: const Text('刪除', style: TextStyle(color: Colors.white)),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('刪除這筆紀錄？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
          ],
        ),
      ),
      onDismissed: (_) => s.records.delete(r.id),
      child: PaperCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          title: Text('${drawTitle(r.number, r.tag)}　${r.deck.label}', style: text.titleMedium),
          subtitle: Text(
            '$date・${s.poems.category(r.categoryId).label}${r.tied ? '・已結籤' : ''}\n'
            '${r.question.isEmpty ? '（未輸入問題）' : r.question}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: Palette.inkSoft),
          ),
          trailing: r.favorite ? const Icon(Icons.bookmark, color: Palette.vermilion) : null,
          onTap: () => context.push('/poem/${r.id}'),
        ),
      ),
    );
  }
}
