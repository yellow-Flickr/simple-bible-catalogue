import 'dart:io';

import '../domain/language_catalog.dart';

class LanguageCatalogRepository {
  const LanguageCatalogRepository(this.directory);

  final Directory directory;

  Future<List<LanguageCatalog>> loadAll() async {
    if (!await directory.exists()) return const [];

    final files = await directory
        .list()
        .where(
          (entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.json'),
        )
        .cast<File>()
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));

    final catalogs = <LanguageCatalog>[];
    for (final file in files) {
      try {
        catalogs.add(LanguageCatalog.fromJson(await file.readAsString()));
      } on FormatException catch (error) {
        throw FormatException(
          'Invalid catalog "${file.path}": ${error.message}',
        );
      } on FileSystemException catch (error) {
        throw FileSystemException(
          'Could not read language catalog: ${error.message}',
          file.path,
        );
      }
    }
    return List.unmodifiable(catalogs);
  }
}
