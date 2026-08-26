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

    testWidgets('tapping a mobile tab switches the hub', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Listen'));
      await tester.pump();

      expect(HubController.instance.currentHub, AppHub.music);
    });

    testWidgets('mobile top bar hides settings icon when onSettingsTap is null', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_rounded), findsNothing);
    });

    testWidgets('mobile top bar shows settings icon and calls onSettingsTap', (tester) async {
      setSurfaceWidth(tester, 400);
      var tapped = false;
      await tester.pumpWidget(wrap(AdaptiveNavShell(
        onSettingsTap: () => tapped = true,
        child: const SizedBox.shrink(),
      )));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();
      expect(tapped, true);
    });

    testWidgets('renders the provided child', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: Text('hub content'))));
      await tester.pumpAndSettle();

      expect(find.text('hub content'), findsOneWidget);
    });
  });
}
