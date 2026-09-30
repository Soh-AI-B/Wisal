import 'package:flutter/material.dart';

/// Google Contacts-style avatar: initials on a soft colour derived from the name.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.radius = 22});
  final String name;
  final double radius;

  static String _first(String s) => String.fromCharCode(s.runes.first);

  String get _initials {
    final p = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.length == 1 ? _first(p[0]) : _first(p[0]) + _first(p[1])).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hue = (name.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0xFFFFFF) % 360).toDouble();
    return CircleAvatar(
      radius: radius,
      backgroundColor: HSLColor.fromAHSL(1, hue, 0.45, dark ? 0.28 : 0.86).toColor(),
      child: Text(
        _initials,
        style: TextStyle(
          color: HSLColor.fromAHSL(1, hue, 0.5, dark ? 0.85 : 0.25).toColor(),
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
