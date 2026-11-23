import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/utils/dates.dart';
import '../../data/models/models.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/pickers.dart';

/// Plan oluşturma / düzenleme. Duraklar sürükle-bırak ile sıralanır.
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key, this.existing, this.initialCountry});
  final PlannedTrip? existing;
  final Country? initialCountry;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  final List<TripStop> _stops = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _notes.text = e.notes;
      _start = e.startDate;
      _end = e.endDate;
      _stops.addAll(e.stops);
    } else if (widget.initialCountry != null) {
      _title.text = '${widget.initialCountry!.nameTr} seyahati';
      _stops.add(TripStop(countryCode: widget.initialCountry!.code, country: widget.initialCountry));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _editStop([int? index]) async {
    final result = await showDialog<TripStop>(
      context: context,
      builder: (_) => _StopDialog(
        existing: index == null ? null : _stops[index],
        isFirst: index == 0 || (index == null && _stops.isEmpty),
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _stops.add(result);
      } else {
        _stops[index] = result;
      }
    });
  }

  Future<void> _save() async {
    if (_start == null) {
      setState(() => _error = 'Başlangıç tarihini seç.');
      return;
    }
    final plan = PlannedTrip(
      id: widget.existing?.id,
      title: _title.text,
      startDate: _start!,
      endDate: _end,
      notes: _notes.text,
      stops: List.of(_stops),
    );
    final services = context.read<AppServices>();
    final err = services.plans.validate(plan);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await services.plans.save(plan);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Yeni plan' : 'Planı düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          ContentWidth(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('planTitle'),
                  controller: _title,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Plan adı *', hintText: 'ör. Balkan turu'),
                ),
                const SizedBox(height: 8),
                DateField(
                  key: const Key('planStart'),
                  label: 'Başlangıç tarihi *',
                  value: _start,
                  firstDate: DateTime(2000),
                  onChanged: (d) => setState(() {
                    _start = d;
                    if (_end != null && d != null && _end!.isBefore(d)) _end = d;
                  }),
                ),
                const SizedBox(height: 12),
                DateField(
                  key: const Key('planEnd'),
                  label: 'Bitiş tarihi (isteğe bağlı)',
                  value: _end,
                  firstDate: _start ?? DateTime(2000),
                  clearable: true,
                  onChanged: (d) => setState(() => _end = d),
                ),
                if (_start != null && _end == null && _stops.any((s) => s.durationDays != null)) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bitiş tarihi boşsa takvimde durak sürelerinin toplamı kullanılır '
                    '(${Dates.duration(_stops.fold(0, (s, e) => s + (e.durationDays ?? 0)))}).',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: Text('Duraklar (${_stops.length})', style: theme.textTheme.titleMedium)),
                    FilledButton.tonalIcon(
                      key: const Key('addStop'),
                      onPressed: () => _editStop(),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Durak ekle'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Sıralamak için tutup sürükle. Ulaşım, bir önceki duraktan bu durağa nasıl gidileceğidir.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                if (_stops.isEmpty)
                  const WtCard(
                    child: Row(
                      children: [
                        Icon(Icons.place_outlined),
                        SizedBox(width: 12),
                        Expanded(child: Text('Henüz durak eklemedin. Ülke ve şehir seçerek başla.')),
                      ],
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _stops.length,
                    onReorder: (from, to) => setState(() {
                      if (to > from) to -= 1;
                      final s = _stops.removeAt(from);
                      _stops.insert(to, s);
                    }),
                    itemBuilder: (_, i) {
                      final s = _stops[i];
                      return Padding(
                        key: ValueKey('stop_${identityHashCode(s)}'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: WtCard(
                          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                          onTap: () => _editStop(i),
                          child: Row(
                            children: [
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_indicator_rounded),
                                ),
                              ),
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: StatusColors.planned,
                                child: Text('${i + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      CountryFlag(code: s.countryCode, width: 20, radius: 3),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(s.city?.nameTr ?? '${s.country?.nameTr ?? s.countryCode} (şehir seçilmedi)',
                                            style: theme.textTheme.titleSmall,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ]),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (s.city != null) s.country?.nameTr ?? s.countryCode,
                                        if (s.durationDays != null) Dates.duration(s.durationDays!),
                                        if (i > 0 && s.transport != null) '${s.transport!.label} ile',
                                        if (s.arrivalDate != null) 'Varış ${Dates.short(s.arrivalDate!)}',
                                      ].join(' · '),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Durağı kaldır',
                                onPressed: () => setState(() => _stops.removeAt(i)),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'Notlar (isteğe bağlı)', alignLabelWithHint: true),
                ),
                if (_error != null) ErrorBox(message: _error!),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ContentWidth(
            maxWidth: 760,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
              key: const Key('savePlan'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Kaydediliyor…' : 'Planı kaydet'),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StopDialog extends StatefulWidget {
  const _StopDialog({this.existing, required this.isFirst});
  final TripStop? existing;
  final bool isFirst;

  @override
  State<_StopDialog> createState() => _StopDialogState();
}

class _StopDialogState extends State<_StopDialog> {
  Country? _country;
  City? _city;
  int _duration = 2;
  TransportType? _transport;
  DateTime? _arrival;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _country = e.country ?? context.read<AppServices>().countries.byCode(e.countryCode);
      _city = e.city;
      _duration = e.durationDays ?? 1;
      _transport = e.transport;
      _arrival = e.arrivalDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Durak ekle' : 'Durağı düzenle'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectField(
                key: const Key('stopCountry'),
                label: 'Ülke',
                value: _country?.nameTr,
                leading: _country == null
                    ? const Icon(Icons.flag_outlined)
                    : CountryFlag(code: _country!.code, width: 28, radius: 4),
                onTap: () async {
                  final c = await pickCountry(context);
                  if (c != null) {
                    setState(() {
                      if (c.code != _country?.code) _city = null;
                      _country = c;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              SelectField(
                key: const Key('stopCity'),
                label: 'Şehir (isteğe bağlı)',
                value: _city?.nameTr,
                enabled: _country != null,
                hint: _country == null ? 'Önce ülke seç' : 'Şehir seç',
                leading: const Icon(Icons.location_city_outlined),
                onTap: () async {
                  final c = await pickCity(context, _country!);
                  if (c != null) setState(() => _city = c);
                },
              ),
              const SizedBox(height: 12),
              DurationField(value: _duration, onChanged: (v) => setState(() => _duration = v), label: 'Kalış süresi'),
              const SizedBox(height: 12),
              DateField(
                label: 'Varış tarihi (isteğe bağlı)',
                value: _arrival,
                clearable: true,
                firstDate: DateTime(2000),
                onChanged: (d) => setState(() => _arrival = d),
              ),
              const SizedBox(height: 14),
              TransportSelector(
                label: widget.isFirst ? 'Ulaşım (bu durağa nasıl gidilecek)' : 'Önceki duraktan ulaşım',
                value: _transport,
                onChanged: (t) => setState(() => _transport = t),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          key: const Key('stopSave'),
          onPressed: _country == null
              ? null
              : () => Navigator.pop(
                    context,
                    TripStop(
                      id: widget.existing?.id,
                      countryCode: _country!.code,
                      country: _country,
                      cityId: _city?.id,
                      city: _city,
                      durationDays: _duration,
                      transport: _transport,
                      arrivalDate: _arrival,
                    ),
                  ),
          child: const Text('Tamam'),
        ),
      ],
    );
  }
}
