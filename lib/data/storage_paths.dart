import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Uygulama verilerinin cihazdaki konumları.
///
/// * Kurulu sürüm: işletim sisteminin uygulama destek klasörü
///   (Windows'ta %APPDATA%\com.furkanbaykal\worldtrack, Android'de uygulamanın özel alanı).
/// * Taşınabilir (portable) Windows sürümü: exe'nin yanında `portable.txt` varsa
///   veriler exe'nin yanındaki `WORLDTRACK-Veri` klasöründe tutulur.
class StoragePaths {
  StoragePaths._(this.root);

  final String root;

  String get databaseFile => p.join(root, 'worldtrack.db');
  String get photosDir => p.join(root, 'photos', 'originals');
  String get thumbsDir => p.join(root, 'photos', 'thumbs');

  bool get isPortable => _portable;
  bool _portable = false;

  static Future<StoragePaths> resolve() async {
    if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      if (File(p.join(exeDir, 'portable.txt')).existsSync()) {
        final paths = StoragePaths._(p.join(exeDir, 'WORLDTRACK-Veri')).._portable = true;
        await paths.ensure();
        return paths;
      }
    }
    final dir = await getApplicationSupportDirectory();
    final paths = StoragePaths._(dir.path);
    await paths.ensure();
    return paths;
  }

  /// Testler için belirli bir klasör.
  static Future<StoragePaths> forDirectory(String dir) async {
    final paths = StoragePaths._(dir);
    await paths.ensure();
    return paths;
  }

  Future<void> ensure() async {
    for (final d in [root, photosDir, thumbsDir]) {
      await Directory(d).create(recursive: true);
    }
  }
}
