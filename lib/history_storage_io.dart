import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'history_storage.dart';

HistoryStorage createHistoryStorage() => IoHistoryStorage();

class IoHistoryStorage implements HistoryStorage {
  IoHistoryStorage({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  Future<File> _file(String name) async {
    final directory = _directory ?? await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}$name');
  }

  @override
  Future<String?> read(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String contents) async {
    final file = await _file(key);
    await file.writeAsString(contents, flush: true);
  }
}
