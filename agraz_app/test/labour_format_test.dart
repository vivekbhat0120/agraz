import 'package:agraz/labour_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment caption is lump sum, not rate × hours', () {
    expect(laborRateHoursCaption('payment', 4000, 1), '₹4000');
    expect(laborRateHoursCaption('PAYMENT', 4500, 1), '₹4500');
  });

  test('labour caption keeps rate × days/hrs', () {
    expect(laborRateHoursCaption('payable', 550, 1), '₹550 × 1');
    expect(laborRateHoursCaption('payable', 550, 0.5), '₹550 × 0.5');
    expect(laborRateHoursCaption(null, 550, 1), '₹550 × 1');
  });

  test('work kind excludes payment, tally and opening', () {
    expect(laborIsWorkKind('payable'), isTrue);
    expect(laborIsWorkKind('opening'), isFalse);
    expect(laborIsWorkKind('payment'), isFalse);
    expect(laborIsWorkKind('tally'), isFalse);
  });

  test('summary nets payments out of labour cost and ignores payment hours', () {
    final t = summarizeLaborEntries([
      {'entry_kind': 'payable', 'wage': 550, 'hours': 10.5, 'date': '2026-08-06'},
      {'entry_kind': 'payment', 'wage': 4000, 'hours': 1, 'date': '2026-08-06'},
      {'entry_kind': 'payment', 'wage': 500, 'hours': 1, 'date': '2026-08-10'},
    ]);
    expect(t.work, 5775);
    expect(t.paid, 4500);
    expect(t.net, 1275);
    expect(t.hours, 10.5);
  });

  test('net from API summary uses payable minus paid, not total_cost', () {
    expect(
      laborNetFromSummary({
        'total_cost': 10275,
        'total_payable': 5775,
        'total_paid': 4500,
      }),
      1275,
    );
  });

  test('OB/Tally both zero resets account to 0', () {
    final t = summarizeLaborEntries([
      {'id': 1, 'entry_kind': 'payable', 'wage': 500, 'hours': 10, 'date': '2026-08-01'},
      {'id': 2, 'entry_kind': 'payment', 'wage': 2000, 'hours': 1, 'date': '2026-08-10'},
      {'id': 3, 'entry_kind': 'tally', 'wage': 0, 'hours': 1, 'date': '2026-08-15'},
      {'id': 4, 'entry_kind': 'payable', 'wage': 400, 'hours': 1, 'date': '2026-08-20'},
    ], applyAccountReset: true);
    expect(t.work, 400);
    expect(t.paid, 0);
    expect(t.net, 400);
    expect(t.hours, 1);
  });

  test('OB payable opening becomes the new starting balance', () {
    final t = summarizeLaborEntries([
      {'id': 1, 'entry_kind': 'payable', 'wage': 800, 'hours': 5, 'date': '2026-07-01'},
      {'id': 2, 'entry_kind': 'opening', 'wage': 3000, 'hours': 1, 'date': '2026-08-01'},
      {'id': 3, 'entry_kind': 'payable', 'wage': 500, 'hours': 2, 'date': '2026-08-05'},
      {'id': 4, 'entry_kind': 'payment', 'wage': 1000, 'hours': 1, 'date': '2026-08-10'},
    ], applyAccountReset: true);
    expect(t.work, 4000); // 3000 opening + 1000 later work
    expect(t.paid, 1000);
    expect(t.net, 3000);
    expect(t.hours, 2);
  });

  test('OB payment opening is a debit starting balance', () {
    final t = summarizeLaborEntries([
      {'id': 1, 'entry_kind': 'payable', 'wage': 900, 'hours': 3, 'date': '2026-07-01'},
      {'id': 2, 'entry_kind': 'opening', 'wage': -1500, 'hours': 1, 'date': '2026-08-01'},
      {'id': 3, 'entry_kind': 'payable', 'wage': 400, 'hours': 1, 'date': '2026-08-04'},
    ], applyAccountReset: true);
    expect(t.work, 400);
    expect(t.paid, 1500);
    expect(t.net, -1100);
  });
}
