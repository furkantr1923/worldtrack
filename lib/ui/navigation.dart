import 'package:flutter/material.dart';

import '../data/models/models.dart';
import 'screens/country_detail_screen.dart';
import 'screens/plan_detail_screen.dart';
import 'screens/plan_editor_screen.dart';
import 'screens/search_screen.dart';
import 'screens/travel_detail_screen.dart';
import 'screens/travel_form_screen.dart';

/// Ekranlar arası geçişler tek yerde toplanır.
class AppNav {
  AppNav._();

  static Future<T?> _push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  static Future<void> country(BuildContext context, String code) =>
      _push(context, CountryDetailScreen(code: code));

  static Future<void> travel(BuildContext context, int id) => _push(context, TravelDetailScreen(recordId: id));

  static Future<int?> newTravel(BuildContext context, {Country? country, City? city}) =>
      _push<int>(context, TravelFormScreen(initialCountry: country, initialCity: city));

  static Future<int?> editTravel(BuildContext context, TravelRecord record) =>
      _push<int>(context, TravelFormScreen(existing: record));

  static Future<void> plan(BuildContext context, int id) => _push(context, PlanDetailScreen(planId: id));

  static Future<int?> newPlan(BuildContext context, {Country? country}) =>
      _push<int>(context, PlanEditorScreen(initialCountry: country));

  static Future<int?> editPlan(BuildContext context, PlannedTrip plan) =>
      _push<int>(context, PlanEditorScreen(existing: plan));

  static Future<void> search(BuildContext context) => _push(context, const SearchScreen());
}
