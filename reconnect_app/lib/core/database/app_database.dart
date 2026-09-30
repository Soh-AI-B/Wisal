import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models.dart';
import '../platform/native_bridge.dart';

const _defaultSettings = <String, String>{
  'backgroundEnabled': '1',
  'language': 'ar',
  'reminderEnabled': '1',
  'reminderCadenceDays': '1',
  'reminderHour': '18',
  'reminderMinute': '0',
  'sentenceEnabled': '1',
  'sentenceHour': '8',
  'sentenceMinute': '0',
};

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  Future<Database> get _d async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'wisal.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE ContactList('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
            'remindAfterDays INTEGER NOT NULL, isKin INTEGER NOT NULL DEFAULT 0, createdAt INTEGER NOT NULL)');
        await db.execute('CREATE TABLE ContactListMember('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, listId INTEGER NOT NULL, '
            'contactLookupKey TEXT NOT NULL, displayName TEXT NOT NULL, '
            'snoozedUntil INTEGER NOT NULL DEFAULT 0, enabled INTEGER NOT NULL DEFAULT 1, '
            'UNIQUE(listId, contactLookupKey))');
        await db.execute('CREATE TABLE LastInteraction('
            'contactLookupKey TEXT PRIMARY KEY, lastCallAt INTEGER NOT NULL, '
            'direction TEXT, phone TEXT)');
        await db.execute('CREATE TABLE ReconnectLog('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, contactLookupKey TEXT NOT NULL, '
            'at INTEGER NOT NULL, direction TEXT)');
        await db.execute('CREATE TABLE AppSettings(k TEXT PRIMARY KEY, v TEXT NOT NULL)');
        final now = DateTime.now().millisecondsSinceEpoch;
        const defaults = <(String, int)>[('Close Friends', 7), ('Family', 14), ('Important People', 30)];
        for (final l in defaults) {
          await db.insert('ContactList', {'name': l.$1, 'remindAfterDays': l.$2, 'createdAt': now});
        }
        for (final e in _defaultSettings.entries) {
          await db.insert('AppSettings', {'k': e.key, 'v': e.value});
        }
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE ContactList ADD COLUMN isKin INTEGER NOT NULL DEFAULT 0');
          await db.execute('CREATE TABLE ReconnectLog('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, contactLookupKey TEXT NOT NULL, '
              'at INTEGER NOT NULL, direction TEXT)');
        }
      },
    );
  }

  // ---- lists
  Future<List<ContactList>> lists() async {
    final r = await (await _d).rawQuery(
        'SELECT l.id, l.name, l.remindAfterDays, l.isKin, '
        '(SELECT COUNT(*) FROM ContactListMember m WHERE m.listId = l.id) AS c '
        'FROM ContactList l ORDER BY l.remindAfterDays, l.id');
    return r
        .map((e) => ContactList(
            id: e['id'] as int,
            name: e['name'] as String,
            days: e['remindAfterDays'] as int,
            count: e['c'] as int,
            isKin: e['isKin'] == 1))
        .toList();
  }

  Future<void> addList(String name, int days, {bool isKin = false}) async {
    await (await _d).insert('ContactList', {
      'name': name,
      'remindAfterDays': days,
      'isKin': isKin ? 1 : 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _changed();
  }

  Future<void> updateList(int id, String name, int days, {bool isKin = false}) async {
    await (await _d).update('ContactList', {'name': name, 'remindAfterDays': days, 'isKin': isKin ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
    await _changed();
  }

  Future<void> deleteList(int id) async {
    final db = await _d;
    await db.delete('ContactListMember', where: 'listId = ?', whereArgs: [id]);
    await db.delete('ContactList', where: 'id = ?', whereArgs: [id]);
    await _changed();
  }

  // ---- members
  Future<Map<String, String>> membersOf(int listId) async {
    final r = await (await _d).query('ContactListMember', where: 'listId = ?', whereArgs: [listId]);
    return {for (final e in r) e['contactLookupKey'] as String: e['displayName'] as String};
  }

  Future<void> setMembers(int listId, Map<String, String> selected) async {
    final db = await _d;
    await db.transaction((t) async {
      final rows = await t.query('ContactListMember',
          columns: ['contactLookupKey'], where: 'listId = ?', whereArgs: [listId]);
      final existing = rows.map((e) => e['contactLookupKey'] as String).toSet();
      for (final k in existing.difference(selected.keys.toSet())) {
        await t.delete('ContactListMember', where: 'listId = ? AND contactLookupKey = ?', whereArgs: [listId, k]);
      }
      for (final e in selected.entries) {
        if (existing.contains(e.key)) {
          await t.update('ContactListMember', {'displayName': e.value},
              where: 'listId = ? AND contactLookupKey = ?', whereArgs: [listId, e.key]);
        } else {
          await t.insert('ContactListMember', {'listId': listId, 'contactLookupKey': e.key, 'displayName': e.value});
        }
      }
    });
    await _changed();
  }

  Future<void> removeMember(int memberId) async {
    await (await _d).delete('ContactListMember', where: 'id = ?', whereArgs: [memberId]);
    await _changed();
  }

  Future<void> snooze(int memberId, DateTime until) async {
    await (await _d).update('ContactListMember', {'snoozedUntil': until.millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [memberId]);
    await _changed();
  }

  Future<List<Person>> people() async {
    final r = await (await _d).rawQuery(
        'SELECT m.id AS mid, m.listId AS listId, m.contactLookupKey AS k, m.displayName AS n, '
        'm.snoozedUntil AS s, l.name AS ln, l.remindAfterDays AS d, l.isKin AS kin, '
        'i.lastCallAt AS lc, i.direction AS dir, i.phone AS ph '
        'FROM ContactListMember m JOIN ContactList l ON l.id = m.listId '
        'LEFT JOIN LastInteraction i ON i.contactLookupKey = m.contactLookupKey');
    return r
        .map((e) => Person(
              memberId: e['mid'] as int,
              listId: e['listId'] as int,
              key: e['k'] as String,
              name: e['n'] as String,
              listName: e['ln'] as String,
              days: e['d'] as int,
              snoozedUntil: e['s'] as int,
              isKin: e['kin'] == 1,
              lastCallAt: e['lc'] as int?,
              direction: e['dir'] as String?,
              phone: e['ph'] as String?,
            ))
        .toList();
  }

  // ---- last interactions (cache filled from the native call-log sync)
  /// Replaces the cache with the latest successful scan (clears members with no match), and
  /// appends a ReconnectLog entry for each contact whose call is genuinely newer than last time
  /// (not for a contact seen for the first time — that's a baseline, not a new reconnect).
  Future<void> saveLast(Map<String, dynamic> calls) async {
    final db = await _d;
    final previous = {
      for (final row in await db.query('LastInteraction')) row['contactLookupKey'] as String: row['lastCallAt'] as int
    };
    await db.transaction((t) async {
      await t.delete('LastInteraction');
      final b = t.batch();
      for (final e in calls.entries) {
        final v = Map<String, dynamic>.from(e.value as Map);
        final at = (v['at'] as num).toInt();
        b.insert('LastInteraction', {
          'contactLookupKey': e.key,
          'lastCallAt': at,
          'direction': v['dir'],
          'phone': v['phone'],
        });
        final before = previous[e.key];
        if (before != null && at > before) {
          b.insert('ReconnectLog', {'contactLookupKey': e.key, 'at': at, 'direction': v['dir']});
        }
      }
      await b.commit(noResult: true);
    });
  }

  /// Distinct contacts reconnected with in the last 7/30 days, from ReconnectLog.
  Future<({int last7, int last30})> stats() async {
    final db = await _d;
    final now = DateTime.now().millisecondsSinceEpoch;
    Future<int> count(int sinceMs) async {
      final r = await db.rawQuery(
          'SELECT COUNT(DISTINCT contactLookupKey) AS c FROM ReconnectLog WHERE at >= ?', [now - sinceMs]);
      return r.first['c'] as int;
    }

    const day = 86400000;
    return (last7: await count(7 * day), last30: await count(30 * day));
  }

  // ---- settings
  Future<String> setting(String k, String def) async {
    final r = await (await _d).query('AppSettings', where: 'k = ?', whereArgs: [k]);
    return r.isEmpty ? def : r.first['v'] as String;
  }

  Future<Map<String, String>> settings() async => {
        for (final e in _defaultSettings.entries) e.key: await setting(e.key, e.value),
      };

  Future<void> setSetting(String k, String v) async {
    await (await _d).insert('AppSettings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
    await _changed();
  }

  /// True while the last attempt to mirror config to the native side failed.
  final ValueNotifier<bool> configDirty = ValueNotifier<bool>(false);

  Future<void> _changed({int attempt = 0}) async {
    try {
      await pushConfig();
    } catch (e) {
      debugPrint('config push failed: $e');
      configDirty.value = true;
      if (attempt < 3) {
        Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)), () => _changed(attempt: attempt + 1));
      }
    }
  }

  /// Mirrors lists, members and settings to the native side so the background
  /// worker, the widget, and the two scheduled notifications work without the Flutter engine.
  Future<void> pushConfig() async {
    final db = await _d;
    final lists = await db.query('ContactList');
    final members = await db.query('ContactListMember');
    final s = await settings();
    final cfg = {
      'language': s['language'],
      'lists': [
        for (final l in lists) {'id': l['id'], 'name': l['name'], 'days': l['remindAfterDays']}
      ],
      'members': [
        for (final m in members)
          {
            'listId': m['listId'],
            'key': m['contactLookupKey'],
            'name': m['displayName'],
            'snoozedUntil': m['snoozedUntil'],
            'enabled': m['enabled'] == 1,
          }
      ],
      'notifications': {
        'reminderEnabled': s['reminderEnabled'] == '1',
        'reminderCadenceDays': int.parse(s['reminderCadenceDays']!),
        'reminderHour': int.parse(s['reminderHour']!),
        'reminderMinute': int.parse(s['reminderMinute']!),
        'sentenceEnabled': s['sentenceEnabled'] == '1',
        'sentenceHour': int.parse(s['sentenceHour']!),
        'sentenceMinute': int.parse(s['sentenceMinute']!),
      },
    };
    await Native.saveConfig(jsonEncode(cfg));
    configDirty.value = false;
  }
}
