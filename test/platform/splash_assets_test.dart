import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android launch background uses editorial notebook and native animation',
    () {
      final launchBackground = File(
        'android/app/src/main/res/drawable/launch_background.xml',
      ).readAsStringSync();
      final launchThemeV31 = File(
        'android/app/src/main/res/values-v31/styles.xml',
      ).readAsStringSync();

      expect(launchBackground, contains('@drawable/splash_notebook'));
      expect(launchBackground, contains('@color/launch_background'));
      expect(launchThemeV31, contains('windowSplashScreenAnimatedIcon'));
      expect(launchThemeV31, contains('@drawable/splash_notebook_animated'));
    },
  );

  test('Generated app icon sources exist', () {
    expect(File('assets/app_icons/app_icon.png').existsSync(), isTrue);
    expect(
      File('assets/app_icons/app_icon_monochrome.png').existsSync(),
      isTrue,
    );
    expect(
      File(
        'android/app/src/main/res/mipmap-xxxhdpi/launch_image.png',
      ).existsSync(),
      isTrue,
    );
  });
}
