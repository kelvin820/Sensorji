import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../logic/haptics.dart';
import '../../logic/sounds.dart';
import '../../logic/session.dart';
import '../../logic/settings.dart';
import '../../logic/shake.dart';
import '../../logic/voice.dart';
import '../../logic/web_device.dart';
import '../widgets/season_scaffold.dart';
import '../widgets/shaker.dart';
import '../widgets/summer_decor.dart';

/// 需要的有效晃動次數（BUILD_PLAN 第 5 節：約 5–8 次）。
const shakesToDraw = 6;

/// 03 搖籤：籤筒隨手機傾斜與晃動擺動（分鏡 ①），晃滿次數（語音模式是放開音量鍵）後落籤（分鏡 ②）。
class ShakeScreen extends StatefulWidget {
  const ShakeScreen({super.key, required this.session});
  final DrawSession session;

  @override
  State<ShakeScreen> createState() => _ShakeScreenState();
}

class _ShakeScreenState extends State<ShakeScreen> {
  ShakeDetector? _detector;
  int _count = 0;
  bool _dropping = false;
  final _shaker = GlobalKey<ShakerState>();
  final _random = Random();

  /// 網頁版 iOS：要先點按允許動作感測才收得到搖晃。
  bool _needMotionPermission = motionPermissionNeeded;

  /// 桌機網頁（或使用者拒絕動作感測）：改成點籤筒／按空白鍵搖一下。
  late bool _tapMode = isDesktopWeb;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_detector != null) return;
    _voiceInput = AppScope.of(context).voice;
    final settings = AppScope.of(context).settings;
    _detector = ShakeDetector(
      sensitivity: settings.sensitivity,
      onShake: (intensity, _) => _onShake(intensity),
    )..start();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  bool get _voice => widget.session.inputMode == InputMode.voice;
  VoiceInput? _voiceInput;

  /// 夏季的風鈴：搖籤時跟著晃、響。
  final _chime = GlobalKey<PendulumState>();
  DateTime _lastFurin = DateTime(0);

  /// 正按著音量鍵或「按住說話」。
  bool _talking = false;

  /// 這次按住說了幾秒（畫面上顯示，讓人知道還在錄）。
  int _talkSeconds = 0;
  Timer? _talkTimer;

  void _startTalkTimer() {
    _talkTimer?.cancel();
    _talkSeconds = 0;
    _talkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _talkSeconds++);
    });
  }

  void _stopTalkTimer() {
    _talkTimer?.cancel();
    _talkTimer = null;
  }

  static final _volumeKeys = {LogicalKeyboardKey.audioVolumeUp, LogicalKeyboardKey.audioVolumeDown};

  /// 語音模式：按住音量鍵說話，放開就當作問題講完、落籤。
  /// 回傳 true 表示吃掉這個按鍵，不讓系統調音量。
  bool _onKey(KeyEvent e) {
    // 桌機：空白鍵（或 Enter）＝搖一下
    if (_tapMode && e is KeyDownEvent && (e.logicalKey == LogicalKeyboardKey.space || e.logicalKey == LogicalKeyboardKey.enter)) {
      _tapShake();
      return true;
    }
    if (!_voice || !_volumeKeys.contains(e.logicalKey)) return false;
    if (e is KeyDownEvent) _talkStart();
    if (e is KeyUpEvent) _talkEnd();
    return true;
  }

  Future<void> _talkStart() async {
    if (_talking || _dropping) return;
    setState(() => _talking = true);
    _startTalkTimer();
    final s = AppScope.of(context);
    if (s.settings.haptics) HapticFeedback.selectionClick();
    final ok = await s.voice.start();
    if (!ok && mounted) {
      _stopTalkTimer();
      setState(() => _talking = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法使用麥克風，請直接搖籤或按「說完了，落籤」')));
    }
  }

  void _talkEnd() {
    if (!_talking) return;
    _talking = false;
    _stopTalkTimer();
    _dropStick(); // 放開＝問題講完（不管搖了幾次）
  }

  /// 「停止錄音，改打字」：把聽到的字帶回提問頁，改用打字繼續。
  Future<void> _switchToTyping() async {
    if (_dropping) return;
    _talking = false;
    _stopTalkTimer();
    final heard = await AppScope.of(context).voice.stop();
    if (!mounted) return;
    context.pop([widget.session.question, heard].where((t) => t.isNotEmpty).join('，'));
  }

  @override
  void dispose() {
    _stopTalkTimer();
    HardwareKeyboard.instance.removeHandler(_onKey);
    // 沒抽完就返回提問頁時，也要關掉麥克風。
    if (_voice && !_dropping) _voiceInput?.stop();
    _detector?.stop();
    super.dispose();
  }

  void _onShake(double intensity) {
    if (_dropping) return;
    final s = AppScope.of(context);
    if (s.settings.haptics) Haptics.shake(intensity);
    Sounds.clack(intensity); // 竹籤在筒裡互碰
    _shaker.currentState?.kick(intensity);
    if (widget.session.season.isSummer) {
      _chime.currentState?.kick(intensity);
      // 風鈴聲不要每下都響：間隔至少 1.2 秒，搖得用力才響
      final now = DateTime.now();
      if (intensity > 0.4 && now.difference(_lastFurin) > const Duration(milliseconds: 1200)) {
        _lastFurin = now;
        Sounds.play(Sfx.furin, volume: 0.35 + 0.4 * intensity);
      }
    }
    setState(() => _count = min(_count + 1, shakesToDraw));
    // 語音模式不看搖晃次數：放開音量鍵（或按「說完了」）才落籤。
    if (!_voice && _count >= shakesToDraw) _dropStick();
  }

  /// 點籤筒搖一下（力道帶一點隨機，籤筒動作才不會每下都一樣）。
  void _tapShake() => _onShake(0.55 + _random.nextDouble() * 0.35);

  /// iOS 網頁：這個呼叫必須直接在點按裡做，不能先 await 別的。
  void _askMotion() {
    requestMotionPermission().then((ok) {
      if (!mounted) return;
      setState(() {
        _needMotionPermission = false;
        _tapMode = _tapMode || !ok;
      });
      if (ok) {
        _detector
          ?..stop()
          ..start();
      }
    });
  }

  Future<void> _dropStick() async {
    if (_dropping) return;
    final s = AppScope.of(context);
    _dropping = true;
    _detector?.stop();
    setState(() {});
    // 籤落出時停止聆聽（辨識器可能要再等一下最終結果，和落籤動畫同時進行）。
    final spoken = _voice ? s.voice.stop() : Future.value('');
    final number = widget.session.number = s.draw.drawNumber(widget.session.deck);
    if (s.settings.haptics) HapticFeedback.selectionClick();
    // 擲筊失敗重搖時縮短落籤動畫
    await _shaker.currentState?.drop(number, quick: widget.session.attempt > 1);
    // 辨識結果接在打的字後面；籤號頁還可以修改。
    final heard = await spoken;
    final typed = widget.session.question;
    widget.session.question = [typed, heard].where((t) => t.isNotEmpty).join('，');
    if (mounted) context.pushReplacement('/number', extra: widget.session);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final text = Theme.of(context).textTheme;
    final fg = seasonText(context, session.season);
    final title = session.attempt > 1 ? '第 ${session.attempt} 次求籤' : '誠心搖籤';
    return SeasonScaffold(
      season: session.season,
      scene: 3,
      decor: session.season.isSummer
          ? Builder(
              builder: (context) {
                final mq = MediaQuery.of(context);
                return Positioned(
                  top: 0,
                  right: 22,
                  child: WindChime(pendulumKey: _chime, height: mq.size.height * 0.17, rope: mq.padding.top + 64),
                );
              },
            )
          : null,
      appBar: AppBar(title: Text(title), foregroundColor: fg),
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (_voice && !_dropping)
            _LiveTranscript(
              voice: AppScope.of(context).voice,
              typed: session.question,
              color: fg,
              seconds: _talking ? _talkSeconds : null,
            )
          else
            Text(
              session.question.isEmpty ? session.category.label : '「${session.question}」',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyLarge?.copyWith(color: fg),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: GestureDetector(
                  onTap: _tapMode && !_dropping ? _tapShake : null,
                  child: Shaker(
                    key: _shaker,
                  label: session.deck == Deck.sensoji ? '觀音籤' : '六十甲子',
                  progress: _count / shakesToDraw,
                  inkColor: fg,
                  onLand: () {
                    if (AppScope.of(context).settings.haptics) Haptics.land();
                    // 籤落地一聲，接著敲磬
                    Sounds.play(Sfx.stickLand);
                    Sounds.play(Sfx.bell, volume: 0.8, delay: const Duration(milliseconds: 320));
                  },
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            label: '搖晃進度 $_count / $shakesToDraw',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < shakesToDraw; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _count ? Palette.vermilion : fg.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_voice) ...[
            Text(
              _talking ? '說完就放開，籤會落下' : '按住音量鍵說出你的問題，邊說邊搖',
              style: text.bodyMedium?.copyWith(color: fg),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // 沒有實體音量鍵（Web、平板）時用這顆：按住說話、放開落籤。
                  Expanded(
                    child: Listener(
                      onPointerDown: (_) => _talkStart(),
                      onPointerUp: (_) => _talkEnd(),
                      onPointerCancel: (_) => _talkEnd(),
                      child: OutlinedButton.icon(
                        onPressed: _dropping ? null : () {},
                        icon: Icon(_talking ? Icons.mic : Icons.mic_none),
                        label: Text(_talking ? '放開落籤' : '按住說話'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _dropping ? null : _dropStick,
                      child: const Text('說完了，落籤'),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _dropping ? null : _switchToTyping,
              style: TextButton.styleFrom(foregroundColor: fg, minimumSize: const Size(44, 48)),
              child: const Text('停止錄音，改打字'),
            ),
          ] else ...[
            if (_needMotionPermission)
              FilledButton(onPressed: _dropping ? null : _askMotion, child: const Text('允許動作感測，開始搖籤'))
            else
              Text(
                _tapMode ? '點一下籤筒（或按空白鍵）搖一下' : '拿穩手機，上下輕搖',
                style: text.bodyMedium?.copyWith(color: fg),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _dropping ? null : _dropStick,
              style: TextButton.styleFrom(foregroundColor: fg, minimumSize: const Size(44, 48)),
              child: const Text('無法搖晃？點此抽籤'),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 語音模式：邊搖邊顯示即時辨識的文字。
class _LiveTranscript extends StatelessWidget {
  const _LiveTranscript({required this.voice, required this.typed, required this.color, this.seconds});
  final VoiceInput voice;
  final String typed;
  final Color color;

  /// 按住說話中：已經說了幾秒；沒在說話時是 null。
  final int? seconds;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final said = [typed, voice.text].where((t) => t.isNotEmpty).join('，');
        return Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(voice.listening ? Icons.mic : Icons.mic_none, size: 18, color: color),
                    const SizedBox(width: 6),
                    Text(voice.listening ? '正在聆聽…' : '麥克風已停止', style: text.bodySmall?.copyWith(color: color)),
                    if (seconds != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${seconds! ~/ 60}:${(seconds! % 60).toString().padLeft(2, '0')}',
                        semanticsLabel: '已錄 $seconds 秒',
                        style: text.bodySmall?.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ],
                    if (voice.listening && voice.level != null) ...[
                      const SizedBox(width: 10),
                      _LevelBars(level: voice.level!, color: color),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  said.isEmpty ? '說出你想問的事' : '「$said」',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(color: color.withValues(alpha: said.isEmpty ? 0.6 : 1)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 小小的音量條：五根，依音量由左到右亮起、中間高兩側低。
class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.level, required this.color});
  final double level;
  final Color color;

  static const _heights = [6.0, 10.0, 14.0, 10.0, 6.0];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        key: const ValueKey('voice-level'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _heights.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: 3 + _heights[i] * (level * 1.4 - i * 0.12).clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: level * 5 > i ? Palette.vermilion : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
