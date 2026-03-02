// This is a basic Flutter widget test for The Borrowed Wings app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:the_borrowed_wings/main.dart';

void main() {
  testWidgets('The Borrowed Wings app loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TheBorrowedWingsApp());

    // Verify that the app title is displayed.
    expect(find.text('The Borrowed Wings'), findsOneWidget);
    
    // Verify that the tagline is displayed.
    expect(find.text('Soar Together, Share Adventures'), findsOneWidget);

    // Verify that the Get Started button is displayed.
    expect(find.text('Get Started'), findsOneWidget);

    // Verify that key features are displayed.
    expect(find.text('Track Flights'), findsOneWidget);
    expect(find.text('Build Community'), findsOneWidget);
    expect(find.text('Share Experiences'), findsOneWidget);
  });

  testWidgets('Get Started button shows snackbar', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TheBorrowedWingsApp());

    // Tap the Get Started button.
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    // Verify that the welcome snackbar is shown.
    expect(find.text('Welcome to The Borrowed Wings! 🪂'), findsOneWidget);
  });
}
