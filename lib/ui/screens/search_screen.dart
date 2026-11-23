import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/models.dart';
import '../navigation.dart';
import '../widgets/common.dart';

/// Ülke ve şehir araması (Türkçe karakter duyarsız). Şehre dokununca o şehir için
/// seyahat kaydı başlatılabilir veya ülke detayı açılabilir.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';
  List<Country> _countries = const [];
  List<City> _cities = const [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _run);
  }

  Future<void> _run() async {
    final q = _query;
    final s = context.read<AppServices>();
    if (q.trim().isEmpty) {
      setState(() {
        _countries = const [];
        _cities = const [];
      });
      return;
    }
    final countries = s.countries.search(q, limit: 8);
    final cities = await s.cities.search(q, limit: 30);
    if (!mounted || q != _query) return;
    setState(() {
      _countries = countries;
      _cities = cities;
    });
  }

  Future<void> _cityActions(City c) async {
    final s = context.read<AppServices>();
    final country = s.countries.byCode(c.countryCode);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(c.nameTr, style: Theme.of(ctx).textTheme.titleMedium),
              subtitle: Text([c.admin1, country?.nameTr ?? ''].where((e) => e.isNotEmpty).join(' · ')),
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Bu şehir için seyahat ekle'),
              onTap: () => Navigator.pop(ctx, 'travel'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text('${country?.nameTr ?? 'Ülke'} detaylarını aç'),
              onTap: () => Navigator.pop(ctx, 'country'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'travel') AppNav.newTravel(context, country: country, city: c);
    if (action == 'country') AppNav.country(context, c.countryCode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.read<AppServices>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            key: const Key('globalSearchField'),
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ülke veya şehir ara (ör. munih, cekya)',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: _onChanged,
          ),
        ),
      ),
      body: _query.trim().isEmpty
          ? const EmptyState(
              icon: Icons.travel_explore_rounded,
              title: 'Ülke ve şehir ara',
              message: 'Türkçe karakter kullanmak zorunlu değil: "istanbul", "İSTANBUL" ve "Istanbul" aynı sonucu verir.',
            )
          : (_countries.isEmpty && _cities.isEmpty)
              ? const EmptyState(icon: Icons.search_off_rounded, title: 'Sonuç yok', message: 'Farklı bir yazım dene.')
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (_countries.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Ülkeler', style: theme.textTheme.titleSmall),
                      ),
                      for (final c in _countries)
                        ListTile(
                          key: Key('searchCountry_${c.code}'),
                          leading: CountryFlag(code: c.code),
                          title: Text(c.nameTr),
                          subtitle: Text([c.capitalTr, c.region].where((e) => e.isNotEmpty).join(' · ')),
                          onTap: () => AppNav.country(context, c.code),
                        ),
                    ],
                    if (_cities.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text('Şehirler', style: theme.textTheme.titleSmall),
                      ),
                      for (final c in _cities)
                        ListTile(
                          key: Key('searchCity_${c.id}'),
                          leading: CountryFlag(code: c.countryCode, width: 30, radius: 4),
                          title: Text(c.nameTr),
                          subtitle: Text([c.admin1, s.countries.byCode(c.countryCode)?.nameTr ?? '']
                              .where((e) => e.isNotEmpty)
                              .join(' · ')),
                          onTap: () => _cityActions(c),
                        ),
                    ],
                  ],
                ),
    );
  }
}
