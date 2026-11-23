import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/dates.dart';

/// Ulaşım türü. Ürün kapsamı gereği yalnızca dört seçenek vardır.
enum TransportType {
  plane('Uçak', Icons.flight_rounded),
  car('Araba', Icons.directions_car_rounded),
  bus('Otobüs', Icons.directions_bus_rounded),
  train('Tren', Icons.train_rounded);

  const TransportType(this.label, this.icon);
  final String label;
  final IconData icon;

  static TransportType? fromDb(String? value) {
    if (value == null) return null;
    for (final t in values) {
      if (t.name == value) return t;
    }
    return null;
  }
}

class Country {
  const Country({
    required this.code,
    required this.nameTr,
    this.nameEn = '',
    this.iso3 = '',
    this.region = '',
    this.subregion = '',
    this.continent = '',
    this.type = '',
    this.capitalTr = '',
    this.capitalEn = '',
    this.capitalCityId,
    this.population,
    this.areaKm2,
    this.currency = '',
    this.currencyName = '',
    this.wikidata = '',
    this.hasShape = false,
    this.labelPoint,
    this.minLabel,
    this.manualVisited = false,
  });

  final String code;
  final String nameTr;
  final String nameEn;
  final String iso3;
  final String region;
  final String subregion;
  final String continent;
  final String type;
  final String capitalTr;
  final String capitalEn;
  final int? capitalCityId;
  final int? population;
  final double? areaKm2;
  final String currency;
  final String currencyName;
  final String wikidata;
  final bool hasShape;
  final LatLng? labelPoint;
  final double? minLabel;

  /// Kullanıcı ayrıntı girmeden "bu ülkeye gittim" olarak işaretlediyse.
  final bool manualVisited;

  String get flagAsset => 'assets/flags/${code.toLowerCase()}.png';

  factory Country.fromRow(Map<String, Object?> r) => Country(
        code: r['code'] as String,
        nameTr: r['name_tr'] as String,
        nameEn: (r['name_en'] as String?) ?? '',
        iso3: (r['iso3'] as String?) ?? '',
        region: (r['region'] as String?) ?? '',
        subregion: (r['subregion'] as String?) ?? '',
        continent: (r['continent'] as String?) ?? '',
        type: (r['type'] as String?) ?? '',
        capitalTr: (r['capital_tr'] as String?) ?? '',
        capitalEn: (r['capital_en'] as String?) ?? '',
        capitalCityId: r['capital_city_id'] as int?,
        population: r['population'] as int?,
        areaKm2: (r['area_km2'] as num?)?.toDouble(),
        currency: (r['currency'] as String?) ?? '',
        currencyName: (r['currency_name'] as String?) ?? '',
        wikidata: (r['wikidata'] as String?) ?? '',
        hasShape: (r['has_shape'] as int? ?? 0) == 1,
        labelPoint: r['label_lat'] != null && r['label_lon'] != null
            ? LatLng((r['label_lat'] as num).toDouble(), (r['label_lon'] as num).toDouble())
            : null,
        minLabel: (r['min_label'] as num?)?.toDouble(),
        manualVisited: (r['manual_visited'] as int? ?? 0) == 1,
      );
}

class City {
  const City({
    required this.id,
    required this.countryCode,
    required this.nameTr,
    this.name = '',
    this.admin1 = '',
    this.lat,
    this.lon,
    this.population = 0,
    this.isCapital = false,
    this.isCustom = false,
  });

  final int id;
  final String countryCode;
  final String nameTr;
  final String name;
  final String admin1;
  final double? lat;
  final double? lon;
  final int population;
  final bool isCapital;

  /// Kullanıcının listede bulamayıp elle eklediği şehir.
  final bool isCustom;

  LatLng? get point => lat != null && lon != null ? LatLng(lat!, lon!) : null;

  /// Aynı adlı şehirleri ayırt etmek için bölge bilgisiyle ad.
  String get subtitle {
    final parts = <String>[];
    if (admin1.isNotEmpty && admin1 != nameTr) parts.add(admin1);
    if (isCustom) parts.add('Elle eklendi');
    return parts.join(' · ');
  }

  factory City.fromRow(Map<String, Object?> r, {String prefix = ''}) => City(
        id: r['${prefix}id'] as int,
        countryCode: r['${prefix}country_code'] as String,
        nameTr: r['${prefix}name_tr'] as String,
        name: (r['${prefix}name'] as String?) ?? '',
        admin1: (r['${prefix}admin1'] as String?) ?? '',
        lat: (r['${prefix}lat'] as num?)?.toDouble(),
        lon: (r['${prefix}lon'] as num?)?.toDouble(),
        population: (r['${prefix}population'] as int?) ?? 0,
        isCapital: (r['${prefix}is_capital'] as int? ?? 0) == 1,
        isCustom: (r['${prefix}is_custom'] as int? ?? 0) == 1,
      );
}

/// Gerçekleşmiş bir seyahat kaydı: bir ülkedeki bir şehre yapılan ziyaret.
class TravelRecord {
  const TravelRecord({
    this.id,
    required this.countryCode,
    required this.cityId,
    required this.visitDate,
    required this.durationDays,
    this.transport,
    this.notes = '',
    this.planId,
    this.city,
    this.country,
    this.photoCount = 0,
    this.coverThumb,
  });

  final int? id;
  final String countryCode;
  final int cityId;
  final DateTime visitDate;
  final int durationDays;
  final TransportType? transport;
  final String notes;
  final int? planId;

  // Listeleme için birleştirilmiş alanlar
  final City? city;
  final Country? country;
  final int photoCount;
  final String? coverThumb;

  DateTime get endDate => Dates.endOf(visitDate, durationDays);

  Map<String, Object?> toRow() => {
        'country_code': countryCode,
        'city_id': cityId,
        'visit_date': Dates.toDb(visitDate),
        'duration_days': durationDays,
        'transport': transport?.name,
        'notes': notes.trim().isEmpty ? null : notes.trim(),
        'plan_id': planId,
      };

  factory TravelRecord.fromRow(Map<String, Object?> r) => TravelRecord(
        id: r['id'] as int,
        countryCode: r['country_code'] as String,
        cityId: r['city_id'] as int,
        visitDate: Dates.fromDb(r['visit_date'] as String),
        durationDays: r['duration_days'] as int,
        transport: TransportType.fromDb(r['transport'] as String?),
        notes: (r['notes'] as String?) ?? '',
        planId: r['plan_id'] as int?,
        city: r['c_id'] != null ? City.fromRow(r, prefix: 'c_') : null,
        photoCount: (r['photo_count'] as int?) ?? 0,
        coverThumb: r['cover_thumb'] as String?,
      );

  TravelRecord withCountry(Country? c) => TravelRecord(
        id: id,
        countryCode: countryCode,
        cityId: cityId,
        visitDate: visitDate,
        durationDays: durationDays,
        transport: transport,
        notes: notes,
        planId: planId,
        city: city,
        country: c,
        photoCount: photoCount,
        coverThumb: coverThumb,
      );
}

class TravelPhoto {
  const TravelPhoto({
    required this.id,
    required this.recordId,
    required this.filePath,
    required this.thumbPath,
    this.originalName = '',
    this.width,
    this.height,
  });

  final int id;
  final int recordId;
  final String filePath;
  final String thumbPath;
  final String originalName;
  final int? width;
  final int? height;

  factory TravelPhoto.fromRow(Map<String, Object?> r) => TravelPhoto(
        id: r['id'] as int,
        recordId: r['record_id'] as int,
        filePath: r['file_path'] as String,
        thumbPath: r['thumb_path'] as String,
        originalName: (r['original_name'] as String?) ?? '',
        width: r['width'] as int?,
        height: r['height'] as int?,
      );
}

enum PlanStatus { planned, completed }

class TripStop {
  const TripStop({
    this.id,
    required this.countryCode,
    this.cityId,
    this.durationDays,
    this.transport,
    this.arrivalDate,
    this.city,
    this.country,
  });

  final int? id;
  final String countryCode;
  final int? cityId;
  final int? durationDays;

  /// Bu durağa bir önceki duraktan nasıl gidileceği (ilk durakta boş olabilir).
  final TransportType? transport;
  final DateTime? arrivalDate;
  final City? city;
  final Country? country;

  String get label => city?.nameTr ?? country?.nameTr ?? countryCode;

  TripStop copyWith({
    int? cityId,
    City? city,
    int? durationDays,
    TransportType? transport,
    bool clearTransport = false,
    DateTime? arrivalDate,
    bool clearArrival = false,
    Country? country,
    String? countryCode,
  }) =>
      TripStop(
        id: id,
        countryCode: countryCode ?? this.countryCode,
        cityId: cityId ?? this.cityId,
        durationDays: durationDays ?? this.durationDays,
        transport: clearTransport ? null : (transport ?? this.transport),
        arrivalDate: clearArrival ? null : (arrivalDate ?? this.arrivalDate),
        city: city ?? this.city,
        country: country ?? this.country,
      );
}

class PlannedTrip {
  const PlannedTrip({
    this.id,
    required this.title,
    required this.startDate,
    this.endDate,
    this.notes = '',
    this.status = PlanStatus.planned,
    this.stops = const [],
  });

  final int? id;
  final String title;
  final DateTime startDate;
  final DateTime? endDate;
  final String notes;
  final PlanStatus status;
  final List<TripStop> stops;

  bool get isCompleted => status == PlanStatus.completed;

  int get totalStopDays => stops.fold(0, (s, e) => s + (e.durationDays ?? 0));

  /// Takvimde gösterilecek son gün: bitiş tarihi, yoksa durak sürelerinin toplamı.
  DateTime get effectiveEnd {
    if (endDate != null) return endDate!;
    final days = totalStopDays;
    return days > 0 ? Dates.endOf(startDate, days) : startDate;
  }

  String get routeSummary => stops.isEmpty ? 'Henüz durak yok' : stops.map((s) => s.label).join(' → ');

  Set<String> get countryCodes => stops.map((s) => s.countryCode).toSet();
}

class Expense {
  const Expense({
    this.id,
    this.recordId,
    this.tripId,
    required this.amountMinor,
    required this.currency,
    required this.category,
    this.description = '',
    this.spentOn,
  });

  final int? id;
  final int? recordId;
  final int? tripId;

  /// Tutar kuruş/sent cinsinden tamsayı olarak saklanır (kayan nokta hatası olmaz).
  final int amountMinor;
  final String currency;
  final String category;
  final String description;
  final DateTime? spentOn;

  double get amount => amountMinor / 100;

  Map<String, Object?> toRow() => {
        'record_id': recordId,
        'trip_id': tripId,
        'amount_minor': amountMinor,
        'currency': currency,
        'category': category,
        'description': description.trim().isEmpty ? null : description.trim(),
        'spent_on': spentOn == null ? null : Dates.toDb(spentOn!),
      };

  factory Expense.fromRow(Map<String, Object?> r) => Expense(
        id: r['id'] as int,
        recordId: r['record_id'] as int?,
        tripId: r['trip_id'] as int?,
        amountMinor: r['amount_minor'] as int,
        currency: r['currency'] as String,
        category: r['category'] as String,
        description: (r['description'] as String?) ?? '',
        spentOn: Dates.tryFromDb(r['spent_on'] as String?),
      );

  static const categories = ['Ulaşım', 'Konaklama', 'Yeme-içme', 'Gezi', 'Alışveriş', 'Diğer'];
}

class TravelStats {
  const TravelStats({required this.visitedCountries, required this.visitedCities});
  final int visitedCountries;
  final int visitedCities;
  static const empty = TravelStats(visitedCountries: 0, visitedCities: 0);
}

class CountryInfo {
  const CountryInfo({required this.summary, required this.url, required this.title, required this.fetchedAt});
  final String summary;
  final String url;
  final String title;
  final DateTime fetchedAt;
}
