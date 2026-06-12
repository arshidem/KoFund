import 'dart:js' as js;

void hideWebSplashImpl() {
  try {
    js.context.callMethod('hideFlutterSplash');
  } catch (e) {
    // Ignore error
  }
}
