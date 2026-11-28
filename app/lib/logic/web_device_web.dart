import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _deviceMotion => globalContext['DeviceMotionEvent'] as JSObject?;

/// iOS（Safari 13 起，iOS 上的其他瀏覽器也一樣）要先由使用者點按、呼叫
/// DeviceMotionEvent.requestPermission() 才收得到搖晃。新版 Chrome 也有這個函式但不需要點按，
/// 所以只在 iOS 上顯示「允許動作感測」。
bool get motionPermissionNeeded {
  final dme = _deviceMotion;
  return dme != null && dme.has('requestPermission') && _isIOS;
}

bool get _isIOS {
  final nav = globalContext['navigator'] as JSObject?;
  final ua = (nav?['userAgent'] as JSString?)?.toDart ?? '';
  final points = (nav?['maxTouchPoints'] as JSNumber?)?.toDartInt ?? 0;
  // iPadOS 預設回報成 Macintosh，用觸控點分辨
  return RegExp('iPhone|iPad|iPod').hasMatch(ua) ||
      (ua.contains('Macintosh') && points > 1);
}

/// 必須在點按的處理函式裡「同步」呼叫（不能先 await 別的東西），否則瀏覽器會拒絕。
Future<bool> requestMotionPermission() async {
  final dme = _deviceMotion;
  if (dme == null || !dme.has('requestPermission')) return true;
  try {
    final result = await dme
        .callMethod<JSPromise<JSString>>('requestPermission'.toJS)
        .toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

/// 沒有觸控點：當作桌機（滑鼠／鍵盤），搖籤改用點按或空白鍵。
bool get isDesktopWeb {
  final nav = globalContext['navigator'] as JSObject?;
  final points = nav?['maxTouchPoints'] as JSNumber?;
  return (points?.toDartInt ?? 0) == 0;
}
