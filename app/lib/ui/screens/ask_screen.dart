import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../logic/session.dart';
import '../../logic/settings.dart';
import '../widgets/common.dart';
import '../widgets/season_scaffold.dart';

const maxQuestionChars = 200;

/// 02 提問：籤種、類別、輸入方式、問題。
class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  late Deck _deck;
  late InputMode _input;
  String? _categoryId;
  final _question = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    final settings = AppScope.of(context).settings;
    _deck = settings.defaultDeck;
    _input = settings.defaultInput;
    _init = true;
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final s = AppScope.of(context);
    if (_input == InputMode.voice) {
      // 先取得麥克風權限；真正收音是在搖籤頁按住音量鍵時（BUILD_PLAN 第 7 節）。
      final ok = await s.voice.prepare();
      s.voice.reset();
      if (!mounted) return;
      if (!ok) {
        setState(() => _input = InputMode.typing);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('無法使用語音（請允許麥克風權限），已改成打字'),
        ));
        return;
      }
    }
    final session = DrawSession(
      deck: _deck,
      category: s.poems.category(_categoryId!),
      inputMode: _input,
      season: s.settings.currentSeason(),
      question: _question.text.trim(),
    );
    context.push('/shake', extra: session);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final season = s.settings.currentSeason();
    final text = Theme.of(context).textTheme;
    return SeasonScaffold(
      season: season,
      scene: 2,
      particles: false,
      appBar: AppBar(title: const Text('你想問什麼？'), foregroundColor: seasonText(context, season)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _label(context, season, '籤種'),
          Row(
            children: [
              for (final d in Deck.values) ...[
                Expanded(child: _DeckCard(deck: d, selected: d == _deck, onTap: () => setState(() => _deck = d))),
                if (d != Deck.values.last) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _label(context, season, '想問的類別'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in s.poems.categories)
                ChoiceChip(
                  label: Text(c.label),
                  tooltip: '分項：${c.itemFor(_deck)}',
                  selected: c.id == _categoryId,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          if (_categoryId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '對應籤上的「${s.poems.category(_categoryId!).itemFor(_deck)}」',
                style: text.bodySmall?.copyWith(color: seasonText(context, season, soft: true)),
              ),
            ),
          const SizedBox(height: 20),
          _label(context, season, '提問方式'),
          SegmentedButton<InputMode>(
            segments: [
              for (final m in InputMode.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_input},
            onSelectionChanged: (v) => setState(() => _input = v.first),
            style: SegmentedButton.styleFrom(backgroundColor: Palette.card),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _question,
            maxLength: maxQuestionChars,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(color: Palette.ink),
            decoration: InputDecoration(
              hintText: _input == InputMode.voice
                  ? '到搖籤頁後，按住音量鍵說出你的心事，放開就落籤'
                  : '把心裡的事寫下來（也可以留白）',
              counterStyle: const TextStyle(color: Palette.inkSoft),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _categoryId == null ? null : _start,
            child: Text(_categoryId == null ? '請先選一個類別' : '開始搖籤'),
          ),
          const SizedBox(height: 16),
          Disclaimer(color: seasonText(context, season, soft: true)),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, season, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: seasonText(context, season))),
      );
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.selected, required this.onTap});

  final Deck deck;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xFFF7E3DA) : Palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? Palette.vermilion : Palette.inkSoft, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deck.label, style: text.titleMedium?.copyWith(color: Palette.ink)),
                const SizedBox(height: 4),
                Text(
                  deck == Deck.sensoji ? '1–100・正版籤紙' : '1–60・可擲筊確認',
                  style: text.bodySmall?.copyWith(color: Palette.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
