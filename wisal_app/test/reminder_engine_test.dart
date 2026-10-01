import 'package:flutter_test/flutter_test.dart';
import 'package:wisal_app/core/models.dart';
import 'package:wisal_app/core/reminder/reminder_engine.dart';

final now = DateTime(2026, 9, 29, 12);
int ago(int d) => now.subtract(Duration(days: d)).millisecondsSinceEpoch;

Person person({int days = 7, int snoozedUntil = 0, int? last, String name = 'A'}) => Person(
      memberId: 1,
      listId: 1,
      key: name,
      name: name,
      listName: 'L',
      days: days,
      snoozedUntil: snoozedUntil,
      lastCallAt: last,
    );

void main() {
  test('overdue exactly at threshold', () {
    expect(ReminderEngine.status(person(last: ago(7)), now), ReminderStatus.overdue);
  });

  test('up to date below threshold', () {
    expect(ReminderEngine.status(person(last: ago(4)), now), ReminderStatus.upToDate);
  });

  test('never contacted is not overdue', () {
    expect(ReminderEngine.status(person(), now), ReminderStatus.never);
  });

  test('snooze wins over overdue, and expires', () {
    final future = now.add(const Duration(days: 1)).millisecondsSinceEpoch;
    final past = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    expect(ReminderEngine.status(person(last: ago(30), snoozedUntil: future), now), ReminderStatus.snoozed);
    expect(ReminderEngine.status(person(last: ago(30), snoozedUntil: past), now), ReminderStatus.overdue);
  });

  test('overdue sorted most overdue first', () {
    final list = ReminderEngine.overdue([
      person(last: ago(9), name: 'B'),
      person(last: ago(20), name: 'C'),
      person(last: ago(1), name: 'D'),
    ], now);
    expect(list.map((p) => p.name).toList(), ['C', 'B']);
  });
}
