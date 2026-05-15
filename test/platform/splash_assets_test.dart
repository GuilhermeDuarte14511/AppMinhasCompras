import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launch background uses generated splash image', () {
    final launchBackground = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final launchThemeV31 = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();

    expect(launchBackground, contains('@mipmap/launch_image'));
    expect(launchBackground, contains('@color/launch_background'));
    expect(launchThemeV31, contains('windowSplashScreenAnimatedIcon'));
    expect(launchThemeV31, contains('@mipmap/launch_image'));
  });

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
