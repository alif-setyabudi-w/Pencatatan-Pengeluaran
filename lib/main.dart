import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'expense.dart';
import 'expense_history_store.dart';

const _categories = [
  'Makanan',
  'Transportasi',
  'Belanja',
  'Tagihan',
  'Lainnya',
];

void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatefulWidget {
  const ExpenseApp({this.historyStore, super.key});

  final ExpenseHistoryStore? historyStore;

  @override
  State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF287A68);
    return MaterialApp(
      title: 'Catatan Pengeluaran',
      restorationScopeId: 'expense-app',
      debugShowCheckedModeBanner: false,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/history') {
          final arguments = settings.arguments! as ExpenseHistoryArguments;
          return MaterialPageRoute<bool>(
            settings: settings,
            builder: (_) => ExpenseHistoryPage(arguments: arguments),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ExpenseHomePage(
            historyStore: widget.historyStore ?? ExpenseHistoryStore(),
            darkMode: _darkMode,
            onThemeChanged: (value) => setState(() => _darkMode = value),
          ),
        );
      },
    );
  }
}

class ExpenseHistoryArguments {
  const ExpenseHistoryArguments({
    required this.entries,
    required this.onClear,
    required this.onUpdate,
    required this.onDelete,
  });

  final List<ExpenseEntry> entries;
  final Future<void> Function() onClear;
  final Future<void> Function(ExpenseEntry original, ExpenseEntry updated)
      onUpdate;
  final Future<void> Function(ExpenseEntry entry) onDelete;
}

class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({
    required this.historyStore,
    required this.darkMode,
    required this.onThemeChanged,
    super.key,
  });

  final ExpenseHistoryStore historyStore;
  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage>
    with RestorationMixin {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final RestorableString _name = RestorableString('');
  final RestorableString _amount = RestorableString('');
  final RestorableString _description = RestorableString('');
  final RestorableString _category = RestorableString(_categories.first);

  List<ExpenseEntry> _entries = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  String? get restorationId => 'expense-home';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_name, 'expense-name');
    registerForRestoration(_amount, 'expense-amount');
    registerForRestoration(_description, 'expense-description');
    registerForRestoration(_category, 'expense-category');
    _nameController.text = _name.value;
    _amountController.text = _amount.value;
    _descriptionController.text = _description.value;
    if (!_categories.contains(_category.value)) {
      _category.value = _categories.first;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _description.dispose();
    _category.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    try {
      final entries = await widget.historyStore.load();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Riwayat gagal dibaca: $error';
        _loading = false;
      });
    }
  }

  Future<void> _saveEntries() async {
    try {
      await widget.historyStore.save(_entries);
      if (mounted) setState(() => _error = null);
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Data gagal disimpan: $error');
    }
  }

  Future<void> _addExpense() async {
    if (_saving) return;
    final name = _name.value.trim();
    final amountText = _amount.value.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);

    if (name.isEmpty) {
      setState(() => _error = 'Nama pengeluaran belum diisi.');
      return;
    }
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = 'Masukkan nominal lebih dari Rp 0.');
      return;
    }

    FocusScope.of(context).unfocus();
    final entry = ExpenseEntry(
      name: name,
      amount: amount,
      category: _category.value,
      createdAt: DateTime.now(),
      description: _description.value.trim(),
    );
    setState(() {
      _saving = true;
      _error = null;
      _entries = [entry, ..._entries];
      _name.value = '';
      _amount.value = '';
      _description.value = '';
      _nameController.clear();
      _amountController.clear();
      _descriptionController.clear();
    });

    await _saveEntries();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _clearHistory() async {
    try {
      await widget.historyStore.save([]);
      if (!mounted) return;
      setState(() {
        _entries = [];
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Riwayat gagal dihapus: $error');
      rethrow;
    }
  }

  Future<void> _updateExpense(
    ExpenseEntry original,
    ExpenseEntry updated,
  ) async {
    final index = _entries.indexOf(original);
    if (index < 0) return;
    final updatedEntries = List<ExpenseEntry>.of(_entries)..[index] = updated;
    try {
      await widget.historyStore.save(updatedEntries);
      if (!mounted) return;
      setState(() {
        _entries = updatedEntries;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Perubahan gagal disimpan: $error');
      rethrow;
    }
  }

  Future<void> _deleteExpense(ExpenseEntry entry) async {
    final updatedEntries = List<ExpenseEntry>.of(_entries)..remove(entry);
    if (updatedEntries.length == _entries.length) return;
    try {
      await widget.historyStore.save(updatedEntries);
      if (!mounted) return;
      setState(() {
        _entries = updatedEntries;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Catatan gagal dihapus: $error');
      rethrow;
    }
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).pushNamed<bool>(
      '/history',
      arguments: ExpenseHistoryArguments(
        entries: List.unmodifiable(_entries),
        onClear: _clearHistory,
        onUpdate: _updateExpense,
        onDelete: _deleteExpense,
      ),
    );
  }

  double get _total => _entries.fold(0, (total, entry) => total + entry.amount);

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CATATAN HARIAN',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                'Catat pengeluaran dengan mudah',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: widget.darkMode ? 'Mode terang' : 'Mode gelap',
          onPressed: () => widget.onThemeChanged(!widget.darkMode),
          icon: Icon(widget.darkMode ? Icons.light_mode : Icons.dark_mode),
        ),
        IconButton.filledTonal(
          key: const Key('open_history'),
          tooltip: 'Riwayat',
          onPressed: _loading ? null : _openHistory,
          icon: const Icon(Icons.history),
        ),
      ],
    );
  }

  Widget _buildTotalCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total pengeluaran tercatat',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatRupiah(_total),
                    key: const Key('expense_total'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text('${_entries.length} catatan'),
                ],
              ),
            ),
            Icon(
              Icons.savings_outlined,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tambah pengeluaran',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('expense_name'),
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) => _name.value = value,
              decoration: const InputDecoration(
                labelText: 'Nama pengeluaran',
                hintText: 'Contoh: Makan siang',
                prefixIcon: Icon(Icons.edit_note),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('expense_amount'),
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (value) => _amount.value = value,
              decoration: const InputDecoration(
                labelText: 'Nominal',
                hintText: 'Contoh: 25000',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('expense_description'),
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 3,
              onChanged: (value) => _description.value = value,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                hintText: 'Tambahkan detail pengeluaran',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const Key('expense_category'),
              value: _category.value,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category.value = value);
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const Key('save_expense'),
                onPressed: _saving ? null : _addExpense,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Simpan pengeluaran'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('expense_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEntries() {
    final recent = _entries.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Terbaru',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: _loading ? null : _openHistory,
              child: const Text('Lihat semua'),
            ),
          ],
        ),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          )
        else if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child:
                Text('Belum ada catatan. Tambahkan pengeluaran pertama Anda.'),
          )
        else
          ...recent.map((entry) => _ExpenseListTile(entry: entry)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final content = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildTotalCard(),
                            const SizedBox(height: 16),
                            _buildRecentEntries(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: _buildForm()),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTotalCard(),
                      const SizedBox(height: 16),
                      _buildForm(),
                      const SizedBox(height: 22),
                      _buildRecentEntries(),
                    ],
                  );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth >= 600 ? 28 : 18,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      content,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExpenseListTile extends StatelessWidget {
  const _ExpenseListTile({
    required this.entry,
    this.onEdit,
    this.onDelete,
  });

  final ExpenseEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(
          _categoryIcon(entry.category),
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(entry.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${entry.category} · ${formatExpenseDate(entry.createdAt)}'),
          if (entry.description.isNotEmpty) Text(entry.description),
        ],
      ),
      isThreeLine: entry.description.isNotEmpty,
      trailing: onEdit == null && onDelete == null
          ? Text(
              formatRupiah(entry.amount),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatRupiah(entry.amount),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key:
                          Key('edit-${entry.createdAt.microsecondsSinceEpoch}'),
                      tooltip: 'Edit ${entry.name}',
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 30),
                      padding: EdgeInsets.zero,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      key: Key(
                          'delete-${entry.createdAt.microsecondsSinceEpoch}'),
                      tooltip: 'Hapus ${entry.name}',
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 30),
                      padding: EdgeInsets.zero,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class ExpenseHistoryPage extends StatefulWidget {
  const ExpenseHistoryPage({required this.arguments, super.key});

  final ExpenseHistoryArguments arguments;

  @override
  State<ExpenseHistoryPage> createState() => _ExpenseHistoryPageState();
}

class _ExpenseHistoryPageState extends State<ExpenseHistoryPage> {
  bool _clearing = false;
  final Set<ExpenseEntry> _processingEntries = {};
  late List<ExpenseEntry> _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.arguments.entries);
  }

  Future<void> _clearHistory() async {
    setState(() {
      _clearing = true;
      _error = null;
    });
    try {
      await widget.arguments.onClear();
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Riwayat gagal dihapus: $error');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _editExpense(ExpenseEntry entry) async {
    final updated = await showDialog<ExpenseEntry>(
      context: context,
      builder: (_) => _ExpenseEditDialog(entry: entry),
    );
    if (updated == null || !mounted) return;

    setState(() {
      _processingEntries.add(entry);
      _error = null;
    });
    try {
      await widget.arguments.onUpdate(entry, updated);
      if (!mounted) return;
      final index = _entries.indexOf(entry);
      if (index >= 0) {
        setState(() => _entries[index] = updated);
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Catatan gagal diperbarui: $error');
    } finally {
      if (mounted) setState(() => _processingEntries.remove(entry));
    }
  }

  Future<void> _deleteExpense(ExpenseEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: Text('Catatan "${entry.name}" akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('confirm_delete_expense'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _processingEntries.add(entry);
      _error = null;
    });
    try {
      await widget.arguments.onDelete(entry);
      if (mounted) setState(() => _entries.remove(entry));
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Catatan gagal dihapus: $error');
    } finally {
      if (mounted) setState(() => _processingEntries.remove(entry));
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestEntry = _entries.isEmpty ? null : _entries.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pengeluaran'),
        actions: [
          TextButton.icon(
            key: const Key('clear_history'),
            onPressed: _entries.isEmpty || _clearing ? null : _clearHistory,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (latestEntry case final latest?)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: const Text('Catatan terbaru'),
                      subtitle: Text(latest.name),
                      trailing: Text(
                        formatRupiah(latest.amount),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(
                          child: Text('Riwayat pengeluaran masih kosong.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            final processing =
                                _processingEntries.contains(entry);
                            return _ExpenseListTile(
                              entry: entry,
                              onEdit:
                                  processing ? null : () => _editExpense(entry),
                              onDelete: processing
                                  ? null
                                  : () => _deleteExpense(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseEditDialog extends StatefulWidget {
  const _ExpenseEditDialog({required this.entry});

  final ExpenseEntry entry;

  @override
  State<_ExpenseEditDialog> createState() => _ExpenseEditDialogState();
}

class _ExpenseEditDialogState extends State<_ExpenseEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late String _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _amountController = TextEditingController(
      text: widget.entry.amount.toString(),
    );
    _descriptionController =
        TextEditingController(text: widget.entry.description);
    _category = widget.entry.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (name.isEmpty) {
      setState(() => _error = 'Nama pengeluaran belum diisi.');
      return;
    }
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = 'Masukkan nominal lebih dari Rp 0.');
      return;
    }
    Navigator.of(context).pop(
      ExpenseEntry(
        name: name,
        amount: amount,
        category: _category,
        createdAt: widget.entry.createdAt,
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit pengeluaran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('edit_expense_name'),
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama pengeluaran'),
            ),
            TextField(
              key: const Key('edit_expense_amount'),
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
              ),
            ),
            TextField(
              key: const Key('edit_expense_description'),
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('edit_expense_category'),
              value: _categories.contains(_category)
                  ? _category
                  : _categories.first,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('save_expense_edit'),
          onPressed: _save,
          child: const Text('Simpan perubahan'),
        ),
      ],
    );
  }
}

IconData _categoryIcon(String category) => switch (category) {
      'Makanan' => Icons.restaurant_outlined,
      'Transportasi' => Icons.directions_bus_outlined,
      'Belanja' => Icons.shopping_bag_outlined,
      'Tagihan' => Icons.receipt_long_outlined,
      _ => Icons.more_horiz,
    };
