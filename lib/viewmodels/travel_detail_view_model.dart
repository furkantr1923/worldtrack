import '../data/models/models.dart';
import 'base_view_model.dart';

class TravelDetailViewModel extends BaseViewModel {
  TravelDetailViewModel(super.services, this.recordId);

  final int recordId;
  TravelRecord? record;
  List<TravelPhoto> photos = const [];
  List<Expense> expenses = const [];
  bool deleted = false;

  int importing = 0;
  int importTotal = 0;
  final List<String> importErrors = [];

  @override
  Future<void> load() async {
    record = await services.travels.byId(recordId);
    if (record == null) {
      deleted = true;
      return;
    }
    photos = await services.travels.photos(recordId);
    expenses = await services.expenses.forRecord(recordId);
  }

  /// Fotoğrafları sırayla içe aktarır; her biri ayrı izolatta işlenir.
  Future<int> addPhotos() async {
    final files = await services.photos.pick();
    if (files.isEmpty) return 0;
    importErrors.clear();
    importTotal = files.length;
    importing = 0;
    notify();
    var added = 0;
    for (final f in files) {
      try {
        final stored = await services.photos.import(f);
        await services.travels.addPhoto(
          recordId: recordId,
          filePath: stored.filePath,
          thumbPath: stored.thumbPath,
          originalName: stored.originalName,
          width: stored.width,
          height: stored.height,
        );
        added++;
      } catch (e) {
        importErrors.add('${f.name}: $e');
      }
      importing++;
      notify();
    }
    importTotal = 0;
    notify();
    return added;
  }

  Future<void> removePhoto(TravelPhoto p) => services.travels.removePhoto(p);

  Future<void> delete() async {
    deleted = true;
    await services.travels.delete(recordId);
  }
}
