import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapagram/models/enums.dart';
import 'package:snapagram/models/story_model.dart';
import 'package:snapagram/screens/explore/explore_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupFirebase();
  });
  testWidgets('Post color should change based on user role',
      (WidgetTester tester) async {
    // Create a list of stories with different user roles
    final stories = [
      StoryModel(
        id: '1',
        uid: '1',
        creatorUsername: 'Walker',
        creatorRole: UserRole.walker,
        type: StoryType.image,
        visibility: StoryVisibility.public,
        mediaUrl: '',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      ),
      StoryModel(
        id: '2',
        uid: '2',
        creatorUsername: 'Owner',
        creatorRole: UserRole.owner,
        type: StoryType.image,
        visibility: StoryVisibility.public,
        mediaUrl: '',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      ),
    ];

    // Build the ExploreScreen with the stories
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExploreScreen(),
          ),
        ),
      ),
    );

    // Verify that the walker's post is green
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Card &&
            (widget.shape as RoundedRectangleBorder).side.color ==
                Colors.green.withOpacity(0.5)),
        findsOneWidget);

    // Verify that the owner's post is blue
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Card &&
            (widget.shape as RoundedRectangleBorder).side.color ==
                Colors.blue.withOpacity(0.5)),
        findsOneWidget);
  });
}