import 'dart:convert';

import 'package:flutter/services.dart';

import '../models.dart';

/// Single bridge to the Kotlin side: permissions, contacts, call-log sync,
/// background scheduling. Permission names: "contacts", "callLog", "notifications".
class Native {
  static const _ch = MethodChannel('wisal/native');

  static Future<bool> granted(String name) async {
    try {
      return await _ch.invokeMethod<bool>('granted', {'name': name}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> request(String name) async {
    try {
      return await _ch.invokeMethod<bool>('request', {'name': name}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<PhoneContact>> listContacts() async {
    final r = await _ch.invokeMethod<List<dynamic>>('listContacts') ?? <dynamic>[];
    return r.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return PhoneContact(m['key'] as String, m['name'] as String);
    }).toList();
  }

  static Future<void> saveConfig(String json) => _ch.invokeMethod('saveConfig', json);

  /// Reads the call log natively and returns {lookupKey: {at, dir, phone}}.
  static Future<Map<String, dynamic>> sync() async {
    final s = await _ch.invokeMethod<String>('sync');
    return s == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(s) as Map);
  }

  static Future<void> schedule(bool on) async {
    try {
      await _ch.invokeMethod('schedule', on);
    } catch (_) {}
  }

  static Future<void> openBatterySettings() async {
    try {
      await _ch.invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  static Future<void> openExactAlarmSettings() async {
    try {
      await _ch.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }

  /// Posts a notification immediately, bypassing every schedule/toggle — for diagnosing why
  /// scheduled notifications aren't showing. Returns 'posted', 'blocked_by_os', or 'security_exception'.
  static Future<String> testNotification() async {
    try {
      return await _ch.invokeMethod<String>('testNotification') ?? 'unknown';
    } catch (e) {
      return 'error: $e';
    }
  }
}
