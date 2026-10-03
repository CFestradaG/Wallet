// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack_gt/firebase_options.dart';

void main() {
  test('Firebase Android options target fintrack-gt', () {
    expect(DefaultFirebaseOptions.android.projectId, 'fintrack-gt');
    expect(
      DefaultFirebaseOptions.android.appId,
      '1:862971153777:android:2b3f32e77981d69fabbad0',
    );
  });
}
