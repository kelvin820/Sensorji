/// 網頁版才需要的裝置能力判斷（iOS 動作感測權限、是不是桌機）。App 版一律回傳「不需要」。
library;

export 'web_device_stub.dart'
    if (dart.library.js_interop) 'web_device_web.dart';
