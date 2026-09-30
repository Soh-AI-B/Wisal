class ContactList {
  const ContactList(
      {required this.id, required this.name, required this.days, required this.count, this.isKin = false});
  final int id;
  final String name;
  final int days;
  final int count;
  final bool isKin;
}

class PhoneContact {
  const PhoneContact(this.key, this.name);
  final String key;
  final String name;
}

enum ReminderStatus { overdue, upToDate, snoozed, never }

/// One membership of a contact in a list, joined with its last interaction.
class Person {
  const Person({
    required this.memberId,
    required this.listId,
    required this.key,
    required this.name,
    required this.listName,
    required this.days,
    required this.snoozedUntil,
    this.isKin = false,
    this.lastCallAt,
    this.direction,
    this.phone,
  });
  final int memberId;
  final int listId;
  final String key;
  final String name;
  final String listName;
  final int days;
  final int snoozedUntil;
  final bool isKin;
  final int? lastCallAt;
  final String? direction;
  final String? phone;
}
