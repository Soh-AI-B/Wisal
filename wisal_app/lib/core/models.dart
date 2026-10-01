import 'package:flutter/material.dart';

import 'theme.dart';

/// Selectable list icons/colors (List Settings → "Color & icon"). Keys are what's stored in sqlite.
const listIcons = <String, IconData>{
  'people': Icons.group_outlined,
  'heart': Icons.favorite_outline,
  'star': Icons.star_outline,
  'briefcase': Icons.work_outline,
  'home': Icons.home_outlined,
};

const listColors = <String, Color>{
  'green': wisalPrimary,
  'orange': wisalSecondary,
  'purple': kinPurple,
  'warm': wisalWarning,
};

IconData listIconFor(ContactList l) => listIcons[l.icon] ?? (l.isKin ? Icons.family_restroom : Icons.group_outlined);
Color listColorFor(ContactList l) => listColors[l.color] ?? (l.isKin ? kinPurple : wisalPrimary);

class ContactList {
  const ContactList({
    required this.id,
    required this.name,
    required this.days,
    required this.count,
    this.isKin = false,
    this.color,
    this.icon,
  });
  final int id;
  final String name;
  final int days;
  final int count;
  final bool isKin;
  final String? color;
  final String? icon;
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
    this.notes,
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
  final String? notes;
}
