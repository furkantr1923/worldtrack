import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:worldtrack/app_services.dart';
import 'package:worldtrack/data/storage_paths.dart';
import 'package:worldtrack/services/photo_service.dart';

/// Testler için geçici klasörde gerçek SQLite veritabanıyla servisleri başlatır.
Future<AppServices> createTestServices(Directory dir, {PhotoSource? photos}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR');
  final paths = await StoragePaths.forDirectory(dir.path);
  return AppServices.initialize(paths: paths, photoSource: photos, startConnectivity: false);
}

Directory tempDir(String name) => Directory.systemTemp.createTempSync('wt_${name}_');
