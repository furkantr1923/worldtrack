import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../data/models/models.dart';

class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Dokununca seçici açan, metin alanı görünümlü satır.
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final Widget? leading;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint ?? '$label seç',
          enabled: enabled,
          prefixIcon: leading == null
              ? null
              : Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: leading),
          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 24),
          suffixIcon: Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
        ),
        child: value == null
            ? null
            : Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.clearable = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;

  Future<void> _pick(BuildContext context) async {
    final last = lastDate ?? DateTime(2100);
    final first = firstDate ?? DateTime(1950);
    var initial = value ?? (Dates.today().isAfter(last) ? last : Dates.today());
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: label,
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (picked != null) onChanged(Dates.dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    return SelectField(
      label: label,
      value: value == null ? null : '${Dates.long(value!)} · ${Dates.weekday(value!)}',
      leading: const Icon(Icons.event_outlined),
      hint: 'Tarih seç',
      onTap: () => _pick(context),
    ).withClear(clearable && value != null ? () => onChanged(null) : null);
  }
}

extension on SelectField {
  Widget withClear(VoidCallback? onClear) {
    if (onClear == null) return this;
    return Row(
      children: [
        Expanded(child: this),
        IconButton(tooltip: 'Tarihi temizle', onPressed: onClear, icon: const Icon(Icons.clear_rounded)),
      ],
    );
  }
}

/// Gün sayısı: −/+ düğmeleriyle dokunmatik ekran dostu sayaç.
class DurationField extends StatelessWidget {
  const DurationField({super.key, required this.value, required this.onChanged, this.label = 'Süre', this.min = 1});

  final int value;
  final ValueChanged<int> onChanged;
  final String label;
  final int min;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.schedule_outlined),
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(Dates.duration(value), style: theme.textTheme.titleMedium, key: const Key('durationValue')),
          ),
          IconButton.filledTonal(
            key: const Key('durationMinus'),
            tooltip: 'Bir gün azalt',
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            key: const Key('durationPlus'),
            tooltip: 'Bir gün artır',
            onPressed: value < 3650 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// Ulaşım seçimi: Uçak, Araba, Otobüs, Tren (isteğe bağlı; tekrar dokununca kaldırılır).
class TransportSelector extends StatelessWidget {
  const TransportSelector({super.key, required this.value, required this.onChanged, this.label = 'Ulaşım'});
  final TransportType? value;
  final ValueChanged<TransportType?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in TransportType.values)
              ChoiceChip(
                key: Key('transport_${t.name}'),
                avatar: Icon(t.icon, size: 18),
                label: Text(t.label),
                selected: value == t,
                onSelected: (sel) => onChanged(sel ? t : null),
              ),
          ],
        ),
      ],
    );
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('formError'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}
