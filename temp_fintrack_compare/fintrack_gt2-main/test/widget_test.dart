import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fintrack_gt/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: FinTrackGTApp()));

    // El contador ya no existe. Validamos que levante la pantalla de Login con el título.
    expect(find.text('FinTrack GT'), findsOneWidget);
  });
}
