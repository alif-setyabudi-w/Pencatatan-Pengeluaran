import 'dart:convert';

import 'expense.dart';
import 'history_storage.dart';
import 'history_storage_stub.dart'
    if (dart.library.io) 'history_storage_io.dart'
    if (dart.library.html) 'history_storage_web.dart' as platform_storage;

class ExpenseHistoryStore {
  ExpenseHistoryStore({HistoryStorage? storage})
      : _storage = storage ?? platform_storage.createHistoryStorage();

  static const _storageKey = 'expense_history.json';
  final HistoryStorage _storage;

  Future<List<ExpenseEntry>> load() async {
    final contents = await _storage.read(_storageKey);
    if (contents == null) return [];

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException(
          'Format file riwayat pengeluaran tidak valid.');
    }
    return decoded
        .map((item) => ExpenseEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<void> save(List<ExpenseEntry> entries) async {
    await _storage.write(
      _storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}
