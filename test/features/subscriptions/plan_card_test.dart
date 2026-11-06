import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/theme/app_theme.dart';
import 'package:hydrotrack/features/subscriptions/data/models/plan.dart';
import 'package:hydrotrack/features/subscriptions/view/widgets/plan_card.dart';

const _standard = Plan(
  key: 'standard',
  name: 'Standard',
  description: 'For growing factories',
  monthlyPrice: 25000,
  maxStaff: 10,
  maxLocations: 1,
  isPopular: true,
);

Future<void> _pump(WidgetTester tester, PlanCard card) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: SingleChildScrollView(child: card)),
  ),
);

void main() {
  testWidgets('shows price, who it is for and what is included', (
    tester,
  ) async {
    var chosen = false;
    await _pump(
      tester,
      PlanCard(
        plan: _standard,
        isCurrent: false,
        isChosen: false,
        onChoose: () => chosen = true,
      ),
    );
    expect(find.text('Most popular'), findsOneWidget);
    expect(find.textContaining('₦25,000'), findsOneWidget);
    expect(find.text('For growing factories'), findsOneWidget);
    expect(find.text('All features'), findsOneWidget);
    expect(find.text('Up to 10 staff users'), findsOneWidget);
    expect(find.text('One factory'), findsOneWidget);
    await tester.tap(find.text('Choose Standard'));
    expect(chosen, isTrue);
  });

  testWidgets('the current plan can be kept; a chosen one waits', (
    tester,
  ) async {
    await _pump(
      tester,
      PlanCard(
        plan: _standard,
        isCurrent: true,
        isChosen: false,
        onChoose: () {},
      ),
    );
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('Keep Standard'), findsOneWidget);

    await _pump(
      tester,
      PlanCard(
        plan: _standard,
        isCurrent: false,
        isChosen: true,
        onChoose: () {},
      ),
    );
    expect(find.text('Chosen · waiting for payment'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('staff who cannot choose see no button', (tester) async {
    await _pump(
      tester,
      const PlanCard(plan: _standard, isCurrent: true, isChosen: false),
    );
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
