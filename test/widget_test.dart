import 'package:flutter_test/flutter_test.dart';
import 'package:kh_battle_ink_prototype/main.dart';

void main() {
  testWidgets('shows variant A lecture ink prototype', (tester) async {
    await tester.pumpWidget(const InkLecturePrototypeApp());

    expect(find.text('A안 · 도구 전환 방식: 상단 메뉴'), findsOneWidget);
    expect(find.text('0787'), findsOneWidget);
    expect(find.text('테스트 시작'), findsOneWidget);
  });

  testWidgets('shows variant B lecture ink prototype', (tester) async {
    await tester.pumpWidget(
      const InkLecturePrototypeApp(initialVariant: PrototypeVariant.b),
    );

    expect(find.text('B안 · 도구 전환 방식: 좌측 하단 버튼'), findsOneWidget);
    expect(find.text('0787'), findsOneWidget);
    expect(find.text('테스트 시작'), findsOneWidget);
  });
}
