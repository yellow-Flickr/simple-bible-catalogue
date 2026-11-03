import 'dart:io';

import 'package:simple_bible_parser/simple_bible_parser.dart';
import 'package:test/test.dart';

void main() {
  test('loads the shipped English book-name catalog', () async {
    final catalogs = await LanguageCatalogRepository(
      Directory('assets/languages'),
    ).loadAll();

    expect(catalogs, hasLength(2));
    final english = catalogs.singleWhere((catalog) => catalog.code == 'en');
    final akuapem = catalogs.singleWhere(
      (catalog) => catalog.code == 'tw' && catalog.dialect == 'Akuapem',
    );
    expect(english.supportsNumbered66BookCanon, isTrue);
    expect(english.bookNames[1], 'Genesis');
    expect(english.bookNames[66], 'Revelation');
    expect(akuapem.supportsNumbered66BookCanon, isTrue);
    expect(akuapem.bookNames[1], '1 Mose (Gyenesis)');
    expect(akuapem.bookNames[66], 'Adiyisɛm');
  });

  test('rejects incomplete or malformed language catalogs', () {
    expect(
      () => LanguageCatalog.fromJson('''
{
  "code": "en",
  "name": "English",
  "canon": "protestant-66",
  "old_testament_book_count": 39,
  "books": {"1": "Genesis", "invalid": "Unknown"}
}
'''),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Invalid book number'),
        ),
      ),
    );
  });
}
