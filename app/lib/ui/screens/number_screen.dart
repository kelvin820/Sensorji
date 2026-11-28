import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../widgets/common.dart';
import '../../data/models.dart';
import '../../logic/draw.dart';
import '../../logic/records.dart';
import '../../logic/session.dart';
import '../widgets/cabinet.dart';
import '../widgets/season_scaffold.dart';
import 'poem_screen.dart' show kFreshDraw;
import 'ask_screen.dart' show maxQuestionChars;

/// 04 籤號落出：籤號、可修改的問題、看籤詩或擲筊確認。
class NumberScreen extends StatefulWidget {
  const NumberScreen({super.key, required this.session});
  final DrawSession session;

  @override
  State<NumberScreen> createState() => _NumberScreenState();
}

class _NumberScreenState extends State<NumberScreen> {
  late final _question = TextEditingController(text: widget.session.question);

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  bool get _needsJiaobei {
    final mode = AppScope.of(context).settings.jiaobei;
    return widget.session.deck == Deck.tw60 && mode != JiaobeiMode.none;
  }

  Future<void> _next() async {
    final session = widget.session..question = _question.text.trim();
    if (_needsJiaobei) {
      context.pushReplacement('/jiaobei', extra: session);
      return;
    }
    final id = await saveDrawn(context, session);
    if (mounted) context.pushReplacement('/poem/$id', extra: kFreshDraw);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final text = Theme.of(context).textTheme;
    return SeasonScaffold(
      season: session.season,
      scene: 4,
      particles: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        children: [
          // 籤櫃背景上方是深色木樑，白天的深色字會看不見，所以墊一塊半透明紙色。
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.card.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                child: Text('籤已落出', style: text.titleLarge?.copyWith(color: Palette.ink)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DrawerCabinet(number: session.number!, deck: session.deck),
          const SizedBox(height: 20),
          QuestionCard(
            controller: _question,
            maxLength: maxQuestionChars,
            label: '你的問題（可修改）',
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _next, child: Text(_needsJiaobei ? '擲筊確認' : '看籤詩')),
        ],
      ),
    );
  }
}

/// 抽到的籤存成紀錄，回傳紀錄 id（籤詩、解說、結籤畫面都用這個 id）。
Future<String> saveDrawn(BuildContext context, DrawSession session) async {
  final s = AppScope.of(context);
  final poem = s.poems.poem(session.deck, session.number!);
  await s.records.save(Reading(
    id: session.id,
    time: DateTime.now(),
    season: session.season,
    deck: session.deck,
    categoryId: session.category.id,
    question: session.question,
    number: poem.number,
    tag: poem.tag,
  ));
  return session.id;
}
