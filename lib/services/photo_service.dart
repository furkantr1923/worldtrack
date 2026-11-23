import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../data/storage_paths.dart';

/// Seçilen bir fotoğrafın uygulama içindeki kopyası.
class StoredPhoto {
  const StoredPhoto({
    required this.filePath,
    required this.thumbPath,
    required this.originalName,
    this.width,
    this.height,
  });

  final String filePath;
  final String thumbPath;
  final String originalName;
  final int? width;
  final int? height;
}

/// Fotoğraf seçme arayüzü (testlerde sahte seçiciyle değiştirilebilir).
abstract class PhotoSource {
  Future<List<XFile>> pickImages();
}

class SystemPhotoSource implements PhotoSource {
  final ImagePicker _picker = ImagePicker();

  /// Android'de sistemin fotoğraf seçicisi kullanılır (depolama izni gerekmez).
  /// Çok büyük görseller 4096 piksele küçültülür; Android HEIC dosyaları JPEG'e çevrilir.
  @override
  Future<List<XFile>> pickImages() =>
      _picker.pickMultiImage(maxWidth: 4096, maxHeight: 4096, imageQuality: 92);
}

/// Fotoğrafları uygulamanın özel klasörüne tek kopya olarak alır ve küçük
/// önizleme (thumbnail) üretir. Ağır işler ayrı bir izolatta çalışır; arayüz donmaz.
class PhotoService {
  PhotoService(this._paths, {PhotoSource? source}) : _source = source ?? SystemPhotoSource();

  final StoragePaths _paths;
  PhotoSource _source;

  set source(PhotoSource s) => _source = s;

  static const int thumbSize = 480;
  final Random _random = Random();

  Future<List<XFile>> pick() => _source.pickImages();

  /// Bir dosyayı içe aktarır. Görsel çözülemezse dosya yine saklanır ve
  /// önizleme olarak kendisi kullanılır (arayüz "önizleme yok" gösterir).
  Future<StoredPhoto> import(XFile file) async {
    final ext = p.extension(file.name).toLowerCase();
    final safeExt = const {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif', '.gif', '.bmp'}.contains(ext)
        ? ext
        : '.jpg';
    final base = '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 30)}';
    final target = p.join(_paths.photosDir, '$base$safeExt');
    final thumb = p.join(_paths.thumbsDir, '$base.jpg');

    await file.saveTo(target);
    final result = await Isolate.run(() => _makeThumbnail(target, thumb, thumbSize));
    return StoredPhoto(
      filePath: target,
      thumbPath: result.ok ? thumb : target,
      originalName: file.name,
      width: result.width,
      height: result.height,
    );
  }

  /// Kaydedilmeden vazgeçilen fotoğrafların dosyalarını temizler.
  Future<void> discard(StoredPhoto photo) async {
    for (final path in {photo.filePath, photo.thumbPath}) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } on FileSystemException {
        // yok sayılır
      }
    }
  }
}

class _ThumbResult {
  const _ThumbResult(this.ok, this.width, this.height);
  final bool ok;
  final int? width;
  final int? height;
}

_ThumbResult _makeThumbnail(String source, String target, int size) {
  try {
    final bytes = File(source).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const _ThumbResult(false, null, null);
    final oriented = img.bakeOrientation(decoded);
    final w = oriented.width, h = oriented.height;
    final resized = w >= h
        ? img.copyResize(oriented, width: w > size ? size : w, interpolation: img.Interpolation.average)
        : img.copyResize(oriented, height: h > size ? size : h, interpolation: img.Interpolation.average);
    File(target).writeAsBytesSync(img.encodeJpg(resized, quality: 82));
    return _ThumbResult(true, w, h);
  } catch (_) {
    return const _ThumbResult(false, null, null);
  }
}
