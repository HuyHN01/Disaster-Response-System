// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:disaster_response_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(
              body: Center(child: Text('Test Home')),
            );
          },
        ),
      ],
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(OmniDisasterApp(router: router));

    // Verify the app builds successfully.
    expect(find.byType(OmniDisasterApp), findsOneWidget);
  });
}
