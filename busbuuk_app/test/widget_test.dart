// widget tests go here
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuuk/widgets/primary_button.dart';

void main() {
  // keeping this Firebase-free since there's no Firebase project wired up yet -
  // just checking the shared button widget behaves correctly
  testWidgets('PrimaryButton shows label and fires onPressed', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Search Buses',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Search Buses'), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('PrimaryButton shows a spinner and ignores taps while loading', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Search Buses',
            isLoading: true,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(tapped, isFalse);
  });
}
