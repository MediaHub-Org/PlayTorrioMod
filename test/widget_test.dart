import 'package:flutter_test/flutter_test.dart';

import 'package:playtorrio/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PlayTorrioApp());

    expect(find.text('PlayTorrio'), findsOneWidget);
  });
}
