import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatindo/core/crypto_service.dart';
import 'package:chatindo/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('theme exposes a usable palette', () {
    final theme = buildAppTheme();
    expect(theme.scaffoldBackgroundColor, isNotNull);
    expect(AppColors.gradientPrimary.length, greaterThanOrEqualTo(2));
  });

  test('per-chat encryption round-trips', () async {
    final crypto = CryptoService.instance;
    final cipher = await crypto.encrypt('chat-1', 'hello world');
    expect(cipher, isNotEmpty);
    expect(await crypto.decrypt('chat-1', cipher), 'hello world');
  });

  test('wrong chat cannot decrypt', () async {
    final crypto = CryptoService.instance;
    final cipher = await crypto.encrypt('chat-1', 'secret');
    expect(await crypto.decrypt('chat-other', cipher), isNull);
  });
}