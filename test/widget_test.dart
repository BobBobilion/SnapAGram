import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapagram/main.dart';

void main() {
  group('SnapAGram App Tests', () {
    testWidgets('App should start without crashing', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());
      
      // Verify that the app starts without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Should show login screen initially', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Wait for the app to load
      await tester.pumpAndSettle();
      
      // Verify login screen elements are present
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });
  });
} 