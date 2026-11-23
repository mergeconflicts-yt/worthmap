import 'package:contour/app/hidden_amounts.dart';
import 'package:contour/app/hide_amounts_button.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/spending/x37_all_payments.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/spending/fake_payments_read_gateway.dart';

void main() {
  testWidgets('the header control hides every amount on a money screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 3400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = HiddenAmountsController(
      store: MemoryHiddenAmountsStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      HiddenAmountsHost(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SectionScope(
            section: Section.spending,
            child: X37AllPayments(
              gateway: FakePaymentsReadGateway(),
              onClose: () {},
              onOpenPayment: (String id) async => null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.hidden, isFalse);
    expect(find.textContaining('6.40'), findsWidgets);

    await tester.tap(find.byType(HideAmountsButton));
    await tester.pumpAndSettle();

    expect(controller.hidden, isTrue);
    expect(find.textContaining('6.40'), findsNothing);
    expect(find.textContaining(hiddenMask), findsWidgets);

    await tester.tap(find.byType(HideAmountsButton));
    await tester.pumpAndSettle();
    expect(controller.hidden, isFalse);
    expect(find.textContaining('6.40'), findsWidgets);
  });
}
