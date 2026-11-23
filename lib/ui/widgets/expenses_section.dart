import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/models.dart';
import '../../data/repositories/expense_repository.dart';
import 'common.dart';
import 'form_fields.dart';

/// Para birimi biçimlendirme (tr_TR: 1.250,50 ₺).
String formatMoney(int minor, String currency) {
  final f = NumberFormat.currency(locale: 'tr_TR', name: currency, symbol: _symbol(currency), decimalDigits: 2);
  return f.format(minor / 100);
}

String _symbol(String c) => const {
      'TRY': '₺',
      'EUR': '€',
      'USD': r'$',
      'GBP': '£',
      'JPY': '¥',
      'CHF': 'CHF ',
    }[c] ??
    '$c ';

const _commonCurrencies = ['TRY', 'EUR', 'USD', 'GBP', 'CHF', 'JPY'];

/// İsteğe bağlı küçük masraf bölümü. Kur çevrimi yapılmaz; her para birimi ayrı toplanır.
class ExpensesSection extends StatelessWidget {
  const ExpensesSection({super.key, this.recordId, this.tripId, required this.expenses, this.defaultCurrency});

  final int? recordId;
  final int? tripId;
  final List<Expense> expenses;
  final String? defaultCurrency;

  Future<void> _edit(BuildContext context, [Expense? e]) async {
    final result = await showDialog<Expense>(
      context: context,
      builder: (_) => _ExpenseDialog(
        existing: e,
        recordId: recordId,
        tripId: tripId,
        defaultCurrency: defaultCurrency,
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await context.read<AppServices>().expenses.save(result);
    } catch (err) {
      if (context.mounted) showMessage(context, friendlyError(err), error: true);
    }
  }

  Future<void> _delete(BuildContext context, Expense e) async {
    final ok = await confirmDialog(context, title: 'Masraf silinsin mi?', message: '${e.category} · ${formatMoney(e.amountMinor, e.currency)}');
    if (ok && context.mounted) await context.read<AppServices>().expenses.delete(e.id!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = ExpenseRepository.totals(expenses);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Masraflar (isteğe bağlı)', action: 'Masraf ekle', onAction: () => _edit(context)),
        WtCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: expenses.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('Masraf kaydı yok'),
                  subtitle: Text('Ulaşım, konaklama gibi harcamaları basitçe not edebilirsin.'),
                )
              : Column(
                  children: [
                    for (final e in expenses)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(_categoryIcon(e.category), color: theme.colorScheme.primary, size: 20),
                        ),
                        title: Text(e.description.isEmpty ? e.category : e.description),
                        subtitle: e.description.isEmpty ? null : Text(e.category),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatMoney(e.amountMinor, e.currency), style: theme.textTheme.titleSmall),
                            PopupMenuButton<String>(
                              tooltip: 'Seçenekler',
                              onSelected: (v) => v == 'edit' ? _edit(context, e) : _delete(context, e),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                PopupMenuItem(value: 'delete', child: Text('Sil')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Toplam', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              totals.entries.map((t) => formatMoney(t.value, t.key)).join('  ·  '),
                              textAlign: TextAlign.end,
                              key: const Key('expenseTotal'),
                              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (totals.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text('Farklı para birimleri kur çevrimi yapılmadan ayrı toplanır.',
                            style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static IconData _categoryIcon(String c) => switch (c) {
        'Ulaşım' => Icons.commute_rounded,
        'Konaklama' => Icons.hotel_rounded,
        'Yeme-içme' => Icons.restaurant_rounded,
        'Gezi' => Icons.museum_rounded,
        'Alışveriş' => Icons.shopping_bag_rounded,
        _ => Icons.receipt_rounded,
      };
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({this.existing, this.recordId, this.tripId, this.defaultCurrency});
  final Expense? existing;
  final int? recordId;
  final int? tripId;
  final String? defaultCurrency;

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  late String _currency;
  late String _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _currency = e?.currency ?? 'TRY';
    _category = e?.category ?? Expense.categories.first;
    if (e != null) {
      _amount.text = NumberFormat('#,##0.00', 'tr_TR').format(e.amount);
      _desc.text = e.description;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  /// "1.250,50" / "1250.50" / "1250" → kuruş. Türkçe ondalık virgül desteklenir.
  static int? parseMinor(String input) {
    var s = input.trim().replaceAll(' ', '');
    if (s.isEmpty) return null;
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      s = s.replaceAll('.', '');
    }
    final v = double.tryParse(s);
    if (v == null || v.isNaN || v.isInfinite) return null;
    return (v * 100).round();
  }

  void _submit() {
    final minor = parseMinor(_amount.text);
    if (minor == null || minor <= 0) {
      setState(() => _error = 'Geçerli bir tutar gir (ör. 1.250,50).');
      return;
    }
    Navigator.pop(
      context,
      Expense(
        id: widget.existing?.id,
        recordId: widget.existing?.recordId ?? widget.recordId,
        tripId: widget.existing?.tripId ?? widget.tripId,
        amountMinor: minor,
        currency: _currency,
        category: _category,
        description: _desc.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencies = {
      ..._commonCurrencies,
      if (widget.defaultCurrency != null && widget.defaultCurrency!.length == 3) widget.defaultCurrency!,
      _currency,
    }.toList();
    return AlertDialog(
      title: Text(widget.existing == null ? 'Masraf ekle' : 'Masrafı düzenle'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      key: const Key('expenseAmount'),
                      controller: _amount,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(labelText: 'Tutar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(labelText: 'Para birimi'),
                      items: [for (final c in currencies) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in Expense.categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _desc,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)'),
              ),
              if (_error != null) ErrorBox(message: _error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(key: const Key('expenseSave'), onPressed: _submit, child: const Text('Kaydet')),
      ],
    );
  }
}

/// Testlerde tutar ayrıştırmayı doğrulamak için dışa açılır.
int? parseMoneyInput(String input) => _ExpenseDialogState.parseMinor(input);
