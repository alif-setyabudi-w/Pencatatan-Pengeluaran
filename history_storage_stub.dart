import 'history_storage.dart';

HistoryStorage createHistoryStorage() => _UnsupportedHistoryStorage();

class _UnsupportedHistoryStorage implements HistoryStorage {
  @override
  Future<String?> read(String key) {
    throw UnsupportedError(
        'Penyimpanan riwayat tidak didukung pada platform ini.');
  }

  @override
  Future<void> write(String key, String contents) {
    throw UnsupportedError(
        'Penyimpanan riwayat tidak didukung pada platform ini.');
  }
}
