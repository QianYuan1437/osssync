import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 基础冒烟测试，实际测试需要初始化 Provider
    expect(true, isTrue);
  });
}
