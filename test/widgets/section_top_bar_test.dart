// test/widgets/section_top_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/utils/app_hub.dart';
import 'package:playtorrio/utils/hub_controller.dart';
import 'package:playtorrio/widgets/common/section_top_bar.dart';

const _dropdownKey = Key('sectionTopBarMobileDropdown');

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    // HubController is a singleton, so reset both axes between tests.
    HubController.instance.setHub(AppHub.media);
    HubController.instance.setCurrentSection('movies');
  });

  group('SectionTopBar', () {
    testWidgets('mobile tier collapses to a dropdown naming the active section',
        (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      expect(find.byKey(_dropdownKey), findsOneWidget);
      // Only the active section is named; the rest are behind the dropdown.
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsNothing);
      expect(find.text('Library'), findsNothing);
    });

    testWidgets('desktop tier shows every section as a chip', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      expect(find.byKey(_dropdownKey), findsNothing);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('mobile dropdown switches the section', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_dropdownKey));
      await tester.pumpAndSettle();

      // 'Series' is unique: it exists only in the open menu, not on the pill.
      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();

      expect(HubController.instance.mediaSection, 'series');
      expect(find.text('Series'), findsOneWidget);
    });

    testWidgets('desktop chip tap switches the section', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anime'));
      await tester.pumpAndSettle();

      expect(HubController.instance.mediaSection, 'anime');
    });

    testWidgets('dropdown follows the active hub', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      HubController.instance.setHub(AppHub.music);
      await tester.pumpAndSettle();

      // Listen defaults to the Music tab, and Watch's sections are gone.
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Movies'), findsNothing);
    });
  });
}
