import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/utils/dates.dart';
import '../../data/models/models.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/pickers.dart';

/// Seyahat ekleme / düzenleme. Zorunlu alanlar: ülke, şehir, tarih, süre.
/// Ulaşım, not ve fotoğraflar isteğe bağlıdır; form kısa tutulmuştur.
class TravelFormScreen extends StatefulWidget {
  const TravelFormScreen({super.key, this.existing, this.initialCountry, this.initialCity});

  final TravelRecord? existing;
  final Country? initialCountry;
  final City? initialCity;

  @override
  State<TravelFormScreen> createState() => _TravelFormScreenState();
}

class _TravelFormScreenState extends State<TravelFormScreen> {
  Country? _country;
  City? _city;
  DateTime? _date;
  int _duration = 1;
  TransportType? _transport;
  final _notes = TextEditingController();
  final List<XFile> _pendingPhotos = [];
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _country = e.country;
      _city = e.city;
      _date = e.visitDate;
      _duration = e.durationDays;
      _transport = e.transport;
      _notes.text = e.notes;
    } else {
      _country = widget.initialCountry;
      _city = widget.initialCity;
      if (_city != null && _country == null) {
        _country = context.read<AppServices>().countries.byCode(_city!.countryCode);
      }
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseCountry() async {
    final c = await pickCountry(context);
    if (c == null) return;
    setState(() {
      if (_country?.code != c.code) _city = null;
      _country = c;
    });
  }

  Future<void> _chooseCity() async {
    final country = _country;
    if (country == null) {
      await _chooseCountry();
      if (_country == null || !mounted) return;
    }
    final city = await pickCity(context, _country!);
    if (city != null) setState(() => _city = city);
  }

  Future<void> _addPhotos() async {
    final files = await context.read<AppServices>().photos.pick();
    if (files.isNotEmpty) setState(() => _pendingPhotos.addAll(files));
  }

  Future<void> _save() async {
    if (_country == null || _city == null || _date == null) {
      setState(() => _error = 'Ülke, şehir ve tarih seçmelisin.');
      return;
    }
    final services = context.read<AppServices>();
    final record = TravelRecord(
      id: widget.existing?.id,
      countryCode: _country!.code,
      cityId: _city!.id,
      visitDate: _date!,
      durationDays: _duration,
      transport: _transport,
      notes: _notes.text,
      planId: widget.existing?.planId,
    );
    final validation = services.travels.validate(record);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    // Aynı şehir + aynı tarih: muhtemel çift kayıt — kullanıcıya sorulur, engellenmez.
    final dup = await services.travels.hasDuplicate(record.cityId, record.visitDate, excludeId: record.id);
    if (dup && mounted) {
      final go = await confirmDialog(
        context,
        title: 'Benzer kayıt var',
        message: '${_city!.nameTr} için ${Dates.long(_date!)} tarihli bir kayıt zaten mevcut. '
            'Yine de yeni kayıt olarak eklensin mi?',
        confirmLabel: 'Yine de kaydet',
        destructive: false,
      );
      if (!go) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      int id;
      if (_isEdit) {
        await services.travels.update(record);
        id = record.id!;
      } else {
        id = await services.travels.insert(record);
      }
      var failed = 0;
      for (final f in _pendingPhotos) {
        try {
          final stored = await services.photos.import(f);
          await services.travels.addPhoto(
            recordId: id,
            filePath: stored.filePath,
            thumbPath: stored.thumbPath,
            originalName: stored.originalName,
            width: stored.width,
            height: stored.height,
          );
        } catch (_) {
          failed++;
        }
      }
      if (!mounted) return;
      if (failed > 0) showMessage(context, '$failed fotoğraf içe aktarılamadı.', error: true);
      Navigator.pop(context, id);
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
      appBar: AppBar(title: Text(_isEdit ? 'Seyahati düzenle' : 'Yeni seyahat')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            ContentWidth(
              maxWidth: 680,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormSectionTitle('Nereye gittin?'),
                  SelectField(
                    key: const Key('fieldCountry'),
                    label: 'Ülke',
                    value: _country?.nameTr,
                    leading: _country == null
                        ? const Icon(Icons.flag_outlined)
                        : CountryFlag(code: _country!.code, width: 30, radius: 4),
                    onTap: _chooseCountry,
                  ),
                  const SizedBox(height: 12),
                  SelectField(
                    key: const Key('fieldCity'),
                    label: 'Şehir',
                    value: _city == null ? null : (_city!.subtitle.isEmpty ? _city!.nameTr : '${_city!.nameTr} · ${_city!.subtitle}'),
                    leading: const Icon(Icons.location_city_outlined),
                    enabled: _country != null,
                    hint: _country == null ? 'Önce ülke seç' : 'Şehir seç',
                    onTap: _chooseCity,
                  ),
                  const SizedBox(height: 20),
                  FormSectionTitle('Ne zaman, ne kadar?'),
                  DateField(
                    key: const Key('fieldDate'),
                    label: 'Varış tarihi',
                    value: _date,
                    lastDate: Dates.today(),
                    onChanged: (d) => setState(() => _date = d),
                  ),
                  const SizedBox(height: 12),
                  DurationField(
                    key: const Key('fieldDuration'),
                    value: _duration,
                    onChanged: (v) => setState(() => _duration = v),
                  ),
                  if (_date != null) ...[
                    const SizedBox(height: 6),
                    Text('${Dates.range(_date!, Dates.endOf(_date!, _duration))} · ${Dates.duration(_duration)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                  ],
                  const SizedBox(height: 20),
                  FormSectionTitle('İsteğe bağlı'),
                  TransportSelector(value: _transport, onChanged: (t) => setState(() => _transport = t)),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('fieldNotes'),
                    controller: _notes,
                    maxLines: 4,
                    minLines: 2,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Kısa bir anı veya not', alignLabelWithHint: true),
                  ),
                  if (!_isEdit) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          key: const Key('formAddPhotos'),
                          onPressed: _addPhotos,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Fotoğraf ekle'),
                        ),
                        const SizedBox(width: 12),
                        if (_pendingPhotos.isNotEmpty)
                          Expanded(
                            child: Text('${_pendingPhotos.length} fotoğraf kaydedilince eklenecek',
                                style: theme.textTheme.bodySmall),
                          ),
                      ],
                    ),
                  ] else
                    Text('Fotoğrafları seyahat detay sayfasından yönetebilirsin.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    ErrorBox(message: _error!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ContentWidth(
            maxWidth: 680,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
              key: const Key('saveTravel'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
