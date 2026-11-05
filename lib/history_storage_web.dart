import 'package:shared_preferences/shared_preferences.dart';

import 'history_storage.dart';

HistoryStorage createHistoryStorage() => WebHistoryStorage();

class WebHistoryStorage implements HistoryStorage {
  @override
  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> write(String key, String contents) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, contents)) {
      throw StateError('Browser menolak menyimpan riwayat pengeluaran.');
    }
  }
}
