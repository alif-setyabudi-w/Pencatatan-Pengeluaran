import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/expense.dart';
import 'package:flutter_application_1/expense_history_store.dart';
import 'package:flutter_application_1/history_storage.dart';
import 'package:flutter_application_1/history_storage_io.dart';
import 'package:flutter_application_1/main.dart';

class MemoryHistoryStorage implements HistoryStorage {
  String? contents;

  @override
  Future<String?> read(String key) async => contents;

  @override
  Future<void> write(String key, String contents) async {
    this.contents = contents;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('expense history persists in a local JSON file', () async {
    final directory = await Directory.systemTemp.createTemp('expenses-test-');
    try {
      final store = ExpenseHistoryStore(
        storage: IoHistoryStorage(directory: directory),
      );
      final entry = ExpenseEntry(
        name: 'Makan siang',
        amount: 25000,
        category: 'Makanan',
        createdAt: DateTime.utc(2025),
        description: 'Makan siang di kantor',
      );

      await store.save([entry]);
      final saved = await store.load();
      expect(saved, hasLength(1));
      expect(saved.single.name, entry.name);
      expect(saved.single.amount, entry.amount);
      expect(saved.single.category, entry.category);
      expect(saved.single.description, entry.description);

      await store.save([]);
      expect(await store.load(), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('formats Indonesian Rupiah', () {
    expect(formatRupiah(125000), 'Rp 125.000');
  });

  testWidgets('adds, edits, and deletes an individual expense', (tester) async {
    final storage = MemoryHistoryStorage();
    final store = ExpenseHistoryStore(storage: storage);

    await tester.pumpWidget(ExpenseApp(historyStore: store));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('expense_name')),
      'Makan siang',
    );
    await tester.enterText(
      find.byKey(const Key('expense_amount')),
      '25000',
    );
    await tester.enterText(
      find.byKey(const Key('expense_description')),
      'Makan siang di kantor',
    );
    await tester.tap(find.byKey(const Key('save_expense')));
    await tester.pumpAndSettle();

    expect(find.text('Rp 25.000'), findsNWidgets(2));
    expect(find.text('1 catatan'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('expense_name')), 'Kopi');
    await tester.enterText(find.byKey(const Key('expense_amount')), '10000');
    await tester.tap(find.byKey(const Key('save_expense')));
    await tester.pumpAndSettle();

    expect(find.text('2 catatan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open_history')));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat Pengeluaran'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
    expect(find.text('Makan siang di kantor'), findsOneWidget);
    expect(find.text('Catatan terbaru'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Makan siang'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('edit_expense_name')),
      'Makan malam',
    );
    await tester.enterText(
      find.byKey(const Key('edit_expense_amount')),
      '30000',
    );
    await tester.enterText(
      find.byKey(const Key('edit_expense_description')),
      'Makan bersama keluarga',
    );
    await tester.tap(find.byKey(const Key('save_expense_edit')));
    await tester.pumpAndSettle();

    expect(find.text('Makan malam'), findsOneWidget);
    expect(find.text('Makan bersama keluarga'), findsOneWidget);
    expect(find.text('Rp 30.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus Makan malam'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_expense')));
    await tester.pumpAndSettle();
    expect(find.text('Kopi'), findsNWidgets(2));
    expect(find.text('Makan malam'), findsNothing);
    final remaining = await store.load();
    expect(remaining, hasLength(1));
    expect(remaining.single.name, 'Kopi');
  });

  testWidgets('adapts to phone and tablet widths without overflow',
      (tester) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });

    for (final size in [const Size(400, 800), const Size(1000, 800)]) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      await tester.pumpWidget(
        ExpenseApp(
          historyStore: ExpenseHistoryStore(storage: MemoryHistoryStorage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense_name')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
