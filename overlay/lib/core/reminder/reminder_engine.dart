import '../models.dart';

class ReminderEngine {
  static int? daysSince(Person p, DateTime now) {
    final at = p.lastCallAt;
    if (at == null || at <= 0) return null;
    return now.difference(DateTime.fromMillisecondsSinceEpoch(at)).inDays;
  }

  static ReminderStatus status(Person p, DateTime now) {
    if (p.snoozedUntil > now.millisecondsSinceEpoch) return ReminderStatus.snoozed;
    final d = daysSince(p, now);
    if (d == null) return ReminderStatus.never;
    return d >= p.days ? ReminderStatus.overdue : ReminderStatus.upToDate;
  }

  /// Overdue people, most overdue first.
  static List<Person> overdue(List<Person> all, DateTime now) {
    final out = all.where((p) => status(p, now) == ReminderStatus.overdue).toList();
    out.sort((a, b) => daysSince(b, now)!.compareTo(daysSince(a, now)!));
    return out;
  }

  /// '↙' they called you last, '↗' you called them last, '' unknown.
  static String directionGlyph(Person p) {
    switch (p.direction) {
      case 'incoming':
        return '↙ ';
      case 'outgoing':
        return '↗ ';
      default:
        return '';
    }
  }

  static String directionLabel(Person p, {bool ar = false}) {
    switch (p.direction) {
      case 'incoming':
        return ar ? 'اتصل بك' : 'They called you';
      case 'outgoing':
        return ar ? 'اتصلت به' : 'You called them';
      default:
        return '';
    }
  }

  static String ago(int? days, {bool ar = false}) {
    if (days == null) return ar ? 'لا يوجد اتصال' : 'No call found';
    if (days == 0) return ar ? 'اليوم' : 'Today';
    if (days == 1) return ar ? 'أمس' : 'Yesterday';
    return ar ? '$days يوماً مضت' : '$days days ago';
  }

  static String statusText(Person p, DateTime now, {bool ar = false}) {
    switch (status(p, now)) {
      case ReminderStatus.snoozed:
        final d = DateTime.fromMillisecondsSinceEpoch(p.snoozedUntil);
        return ar ? 'مؤجل حتى ${d.day}/${d.month}' : 'Snoozed until ${d.day}/${d.month}';
      case ReminderStatus.never:
        return ar ? 'لا يوجد اتصال' : 'No call found';
      default:
        return ago(daysSince(p, now), ar: ar);
    }
  }
}
