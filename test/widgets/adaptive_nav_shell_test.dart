// test/widgets/adaptive_nav_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/utils/app_hub.dart';
import 'package:playtorrio/utils/hub_controller.dart';
import 'package:playtorrio/widgets/common/adaptive_nav_shell.dart';
import 'package:playtorrio/widgets/common/top_bar.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    HubController.instance.setHub(AppHub.media);
  });

  group('AdaptiveNavShell', () {
    testWidgets('mobile tier shows the bottom tab bar, not TopBar', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsOneWidget);
      expect(find.byType(TopBar), findsNothing);
      expect(find.text('Watch'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
    });

    testWidgets('tablet tier shows TopBar, not the bottom tab bar', (tester) async {
      setSurfaceWidth(tester, 700);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byType(TopBar), findsOneWidget);
      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsNothing);
    });

    testWidgets('desktop tier shows TopBar, not the bottom tab bar', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byType(TopBar), findsOneWidget);
      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsNothing);
    });
  });
}
