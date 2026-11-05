class ExpenseEntry {
  const ExpenseEntry({
    required this.name,
    required this.amount,
    required this.category,
    required this.createdAt,
    this.description = '',
  });

  final String name;
  final double amount;
  final String category;
  final DateTime createdAt;
  final String description;

  Map<String, Object> toJson() => {
        'name': name,
        'amount': amount,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
      };

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String? ?? '',
    );
  }
}

String formatRupiah(double amount) {
  final value = amount.round().toString();
  final grouped = value.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'Rp $grouped';
}

String formatExpenseDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} · $hour:$minute';
}
