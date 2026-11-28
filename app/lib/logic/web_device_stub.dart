/// App 版：感測器不需要另外請求權限，也一定是手機／平板。
bool get motionPermissionNeeded => false;

Future<bool> requestMotionPermission() async => true;

bool get isDesktopWeb => false;

/// App 版：Android 的 SpeechRecognizer；真的不能用時，提問頁按開始會退回打字。
bool get voiceSupported => true;
