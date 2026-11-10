abstract interface class HistoryStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String contents);
}
