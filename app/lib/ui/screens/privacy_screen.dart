import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/season_scaffold.dart';
import '../../logic/season.dart';

/// 隱私權政策全文（assets/docs/privacy.txt）。網頁版另有 /privacy.html 讀同一份檔案，
/// 給 Play Console 填網址用；內容只改這一份。
const kPrivacyAsset = 'assets/docs/privacy.txt';

/// 簡單的排版：「# 」標題、「## 」小標、「- 」條列，其他是段落。
List<Widget> renderPrivacy(String src, TextTheme text) {
  final out = <Widget>[];
  for (final raw in src.split('\n')) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    if (line.startsWith('## ')) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(line.substring(3), style: text.titleMedium, semanticsLabel: line.substring(3)),
      ));
    } else if (line.startsWith('# ')) {
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Semantics(header: true, child: Text(line.substring(2), style: text.headlineSmall)),
      ));
    } else if (line.startsWith('- ')) {
      out.add(Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('・', style: text.bodyMedium),
            Expanded(child: Text(line.substring(2), style: text.bodyMedium?.copyWith(height: 1.6))),
          ],
        ),
      ));
    } else {
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(line, style: text.bodyMedium?.copyWith(height: 1.6)),
      ));
    }
  }
  return out;
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SeasonScaffold(
      season: Season.autumn,
      appBar: AppBar(title: const Text('隱私權政策')),
      child: FutureBuilder<String>(
        future: rootBundle.loadString(kPrivacyAsset),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink(); // 本機檔案，瞬間就讀完
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: renderPrivacy(snap.data!, text),
          );
        },
      ),
    );
  }
}
