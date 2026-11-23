import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/models.dart';
import 'common.dart';

/// Ülke seçici: Türkçe karakter duyarsız arama.
Future<Country?> pickCountry(BuildContext context, {String title = 'Ülke seç'}) {
  return _showPicker<Country>(context, (ctx) => _CountryPicker(title: title));
}

/// Seçilen ülkenin şehirleri içinde arama; bulunamazsa elle ekleme.
Future<City?> pickCity(BuildContext context, Country country) {
  return _showPicker<City>(context, (ctx) => _CityPicker(country: country));
}

Future<T?> _showPicker<T>(BuildContext context, WidgetBuilder builder) {
  if (isWide(context)) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.85, child: builder(ctx)),
  );
}

class _PickerScaffold extends StatelessWidget {
  const _PickerScaffold({required this.title, required this.field, required this.body, this.footer});
  final String title;
  final Widget field;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: field),
        const SizedBox(height: 8),
        Expanded(child: body),
        if (footer != null) footer!,
      ],
    );
  }
}

class _CountryPicker extends StatefulWidget {
  const _CountryPicker({required this.title});
  final String title;

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppServices>().countries;
    final results = repo.search(_query, limit: 300);
    return _PickerScaffold(
      title: widget.title,
      field: TextField(
        key: const Key('countrySearchField'),
        autofocus: isWide(context),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Ülke ara (ör. italya, Türkiye)'),
        onChanged: (v) => setState(() => _query = v),
      ),
      body: results.isEmpty
          ? const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Ülke bulunamadı',
              message: 'Farklı bir yazım dene. Türkçe karakter kullanmak zorunlu değil.')
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, i) {
                final c = results[i];
                return ListTile(
                  key: Key('countryOption_${c.code}'),
                  leading: CountryFlag(code: c.code),
                  title: Text(c.nameTr),
                  subtitle: Text([c.capitalTr, c.region].where((s) => s.isNotEmpty).join(' · ')),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
    );
  }
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.country});
  final Country country;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';
  List<City> _results = const [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    final repo = context.read<AppServices>().cities;
    final q = _query;
    final r = await repo.search(q, countryCode: widget.country.code, limit: 60);
    if (!mounted || q != _query) return;
    setState(() {
      _results = r;
      _loading = false;
    });
  }

  void _onChanged(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), _search);
  }

  Future<void> _addCustom() async {
    final city = await showDialog<City>(
      context: context,
      builder: (_) => _CustomCityDialog(country: widget.country, initialName: _query),
    );
    if (city != null && mounted) Navigator.pop(context, city);
  }

  @override
  Widget build(BuildContext context) {
    return _PickerScaffold(
      title: '${widget.country.nameTr} · Şehir seç',
      field: TextField(
        key: const Key('citySearchField'),
        autofocus: isWide(context),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Şehir ara'),
        onChanged: _onChanged,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? EmptyState(
                  icon: Icons.location_city_rounded,
                  title: 'Şehir bulunamadı',
                  message: 'Listede yalnızca nüfusu 15.000\'in üzerindeki yerleşimler var. '
                      'Aradığın yeri elle ekleyebilirsin.',
                  action: FilledButton.icon(
                    onPressed: _addCustom,
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Şehri elle ekle'),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final c = _results[i];
                    return ListTile(
                      key: Key('cityOption_${c.id}'),
                      leading: Icon(c.isCapital ? Icons.star_rounded : Icons.location_on_outlined,
                          color: c.isCapital ? StatusColors.planned : null),
                      title: Text(c.nameTr),
                      subtitle: c.subtitle.isEmpty ? null : Text(c.subtitle),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
      footer: _results.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextButton.icon(
                  onPressed: _addCustom,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Aradığın yer listede yok mu? Elle ekle'),
                ),
              ),
            ),
    );
  }
}

class _CustomCityDialog extends StatefulWidget {
  const _CustomCityDialog({required this.country, required this.initialName});
  final Country country;
  final String initialName;

  @override
  State<_CustomCityDialog> createState() => _CustomCityDialogState();
}

class _CustomCityDialogState extends State<_CustomCityDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName.trim());
  final _region = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _region.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  double? _parse(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final lat = _parse(_lat.text), lon = _parse(_lon.text);
    if ((_lat.text.trim().isNotEmpty && lat == null) || (_lon.text.trim().isNotEmpty && lon == null)) {
      setState(() => _error = 'Koordinatlar sayı olmalı (ör. 41,0082).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final city = await context.read<AppServices>().cities.addCustom(
            countryCode: widget.country.code,
            name: _name.text,
            admin1: _region.text,
            lat: lat,
            lon: lon,
          );
      if (mounted) Navigator.pop(context, city);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\-]'));
    return AlertDialog(
      title: const Text('Şehri elle ekle'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.country.nameTr} için yeni bir yer ekleniyor.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                key: const Key('customCityName'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Yer adı *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _region,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Bölge / il (isteğe bağlı)'),
              ),
              const SizedBox(height: 16),
              Text('Konum (isteğe bağlı)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Bilmiyorsan boş bırak; uygulama konum tahmin etmez. Konumsuz yerler rota haritasında '
                'nokta olarak gösterilmez.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [coordFormatter],
                      decoration: const InputDecoration(labelText: 'Enlem'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lon,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [coordFormatter],
                      decoration: const InputDecoration(labelText: 'Boylam'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          key: const Key('customCitySave'),
          onPressed: _saving ? null : _save,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
