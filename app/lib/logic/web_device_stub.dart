/// App 版：感測器不需要另外請求權限，也一定是手機／平板。
bool get motionPermissionNeeded => false;

Future<bool> requestMotionPermission() async => true;

bool get isDesktopWeb => false;
