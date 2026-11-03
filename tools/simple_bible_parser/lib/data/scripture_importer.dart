import 'dart:convert';

import 'package:xml/xml.dart';

import '../domain/language_catalog.dart';
import '../domain/scripture.dart';

class ScriptureImporter {
  ScriptureImporter({List<XmlScriptureParser>? xmlParsers})
    : xmlParsers = List.unmodifiable(
        xmlParsers ?? const [XmlBibleParser(), NestedTestamentXmlParser()],
      );

  final List<XmlScriptureParser> xmlParsers;

  Scripture fromJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Input is not valid JSON: ${error.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected a JSON object in Scripture output format.',
      );
    }

    final id = _requiredString(decoded, 'id', 'root');
    final versionName = _requiredString(decoded, 'version_name', 'root');
    final languageData = decoded['language'];
    if (languageData is! Map<String, dynamic>) {
      throw const FormatException('Expected an object at "language".');
    }

    final versionData = decoded['version'];
    if (versionData is! List) {
      throw const FormatException('Expected an array at "version".');
    }
    if (versionData.isEmpty) {
      throw const FormatException('Expected at least one verse at "version".');
    }

    final versions = <Version>[];
    for (var index = 0; index < versionData.length; index++) {
      final item = versionData[index];
      final path = 'version[$index]';
      if (item is! Map<String, dynamic>) {
        throw FormatException('Expected an object at "$path".');
      }

      versions.add(
        Version(
          id: _requiredInt(item, 'id', path),
          chapter: _requiredInt(item, 'chapter', path),
          verse: _requiredInt(item, 'verse', path),
          text: _requiredString(item, 'text', path),
          translationId: _requiredString(item, 'translation_id', path),
          bookId: _requiredInt(item, 'book_id', path),
          bookName: _requiredString(item, 'book_name', path),
          testament: _requiredString(item, 'testament', path),
        ),
      );
    }

    return Scripture(
      id: id,
      versionName: versionName,
      language: Language(
        code: _requiredString(languageData, 'code', 'language'),
        name: _requiredString(languageData, 'name', 'language'),
        dialect: _requiredString(
          languageData,
          'dialect',
          'language',
          allowEmpty: true,
        ),
      ),
      version: versions,
    );
  }

  Scripture fromXmlBible(
    String source, {
    required ScriptureImportMetadata metadata,
  }) {
    return fromXml(source, metadata: metadata);
  }

  Scripture fromXml(
    String source, {
    required ScriptureImportMetadata metadata,
  }) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(source);
    } on XmlException catch (error) {
      throw FormatException('Input is not valid XML: $error');
    }

    final root = document.rootElement;
    final applicableParsers = xmlParsers
        .where((parser) => parser.supports(root))
        .toList();
    if (applicableParsers.isEmpty) {
      final parserNames = xmlParsers.map((parser) => parser.name).join(', ');
      throw FormatException(
        'No XML parser recognized root "${root.name.local}". '
        'Available parsers: $parserNames.',
      );
    }

    final errors = <String>[];
    final missingBookIds = <int>{};
    for (final parser in applicableParsers) {
      try {
        return parser.parse(root, metadata: metadata);
      } on MissingScriptureDataException catch (error) {
        missingBookIds.addAll(error.bookIds);
      } on FormatException catch (error) {
        errors.add('${parser.name}: ${error.message}');
      }
    }

    if (missingBookIds.isNotEmpty) {
      throw MissingScriptureDataException(missingBookIds.toList()..sort());
    }

    throw FormatException(
      'All matching XML parsers failed:\n${errors.join('\n')}',
    );
  }

  String _requiredString(
    Map<String, dynamic> data,
    String key,
    String parentPath, {
    bool allowEmpty = false,
  }) {
    final value = data[key];
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException(
        'Expected a non-empty string at "$parentPath.$key".',
      );
    }
    return value;
  }

  int _requiredInt(Map<String, dynamic> data, String key, String parentPath) {
    final value = data[key];
    if (value is! int) {
      throw FormatException('Expected an integer at "$parentPath.$key".');
    }
    return value;
  }
}

abstract interface class XmlScriptureParser {
  String get name;

  bool supports(XmlElement root);

  Scripture parse(XmlElement root, {required ScriptureImportMetadata metadata});
}

class XmlBibleParser implements XmlScriptureParser {
  const XmlBibleParser();

  @override
  String get name => 'XMLBIBLE parser';

  @override
  bool supports(XmlElement root) => root.name.local.toUpperCase() == 'XMLBIBLE';

  @override
  Scripture parse(
    XmlElement root, {
    required ScriptureImportMetadata metadata,
  }) {
    final books = root.childElements
        .where((element) => element.name.local.toUpperCase() == 'BIBLEBOOK')
        .toList();
    if (books.isEmpty) {
      throw const FormatException('No BIBLEBOOK elements found.');
    }

    final versions = <Version>[];
    for (var bookIndex = 0; bookIndex < books.length; bookIndex++) {
      final book = books[bookIndex];
      final bookPath = 'BIBLEBOOK[${bookIndex + 1}]';
      final bookId = _requiredXmlInt(book, 'bnumber', bookPath);
      final bookName = _requiredXmlString(book, 'bname', bookPath);
      final chapters = book.childElements.where(
        (element) => element.name.local.toUpperCase() == 'CHAPTER',
      );
      for (final chapterElement in chapters) {
        final chapter = _requiredXmlInt(
          chapterElement,
          'cnumber',
          '$bookPath/CHAPTER',
        );
        final verses = chapterElement.childElements.where(
          (element) => element.name.local.toUpperCase() == 'VERS',
        );
        for (final verseElement in verses) {
          final verse = _requiredXmlInt(
            verseElement,
            'vnumber',
            '$bookPath/CHAPTER[$chapter]/VERS',
          );
          versions.add(
            Version(
              id: versions.length,
              chapter: chapter,
              verse: verse,
              text: _verseText(verseElement, '$bookPath/$chapter/$verse'),
              translationId: metadata.translationId,
              bookId: bookId,
              bookName: bookName,
              testament: bookId <= 39
                  ? metadata.oldTestamentName
                  : metadata.newTestamentName,
            ),
          );
        }
      }
    }

    return _scripture(metadata, versions);
  }
}

class NestedTestamentXmlParser implements XmlScriptureParser {
  const NestedTestamentXmlParser();

  @override
  String get name => 'nested testament parser';

  @override
  bool supports(XmlElement root) {
    final rootTag = root.name.local.toLowerCase();
    final bible = rootTag == 'bible'
        ? root
        : root.childElements
              .where((child) => child.name.local.toLowerCase() == 'bible')
              .firstOrNull;
    return bible != null &&
        bible.childElements.any(
          (child) => child.name.local.toLowerCase() == 'testament',
        );
  }

  @override
  Scripture parse(
    XmlElement root, {
    required ScriptureImportMetadata metadata,
  }) {
    final bible = root.name.local.toLowerCase() == 'bible'
        ? root
        : root.childElements.firstWhere(
            (child) => child.name.local.toLowerCase() == 'bible',
          );
    final testaments = bible.childElements
        .where((element) => element.name.local.toLowerCase() == 'testament')
        .toList();
    final booksByTestament = testaments
        .map(
          (testament) => testament.childElements
              .where((element) => element.name.local.toLowerCase() == 'book')
              .toList(),
        )
        .toList();
    final allBookIds = <int>[];
    for (final books in booksByTestament) {
      for (final book in books) {
        allBookIds.add(
          _requiredXmlInt(
            book,
            'number',
            'bible/testament/book',
            alternatives: const ['bnumber', 'id'],
          ),
        );
      }
    }
    final useCatalog = _matchesNumbered66BookCanon(
      booksByTestament,
      allBookIds,
      metadata.languageCatalogBookNames,
      metadata.languageCatalogMatchesNumbered66BookCanon,
    );
    final versions = <Version>[];
    final missingBookIds = <int>{};

    for (
      var testamentIndex = 0;
      testamentIndex < testaments.length;
      testamentIndex++
    ) {
      final testamentElement = testaments[testamentIndex];
      final testamentName = testamentElement.getAttribute('name')?.trim();
      for (final book in booksByTestament[testamentIndex]) {
        const bookPath = 'bible/testament/book';
        final bookId = _requiredXmlInt(
          book,
          'number',
          bookPath,
          alternatives: const ['bnumber', 'id'],
        );
        final bookName =
            _optionalXmlString(book, const ['name', 'bname', 'title']) ??
            metadata.bookNames[bookId] ??
            (useCatalog ? metadata.languageCatalogBookNames[bookId] : null);
        if (bookName == null) {
          missingBookIds.add(bookId);
          continue;
        }
        final chapters = book.childElements.where(
          (element) => element.name.local.toLowerCase() == 'chapter',
        );
        for (final chapterElement in chapters) {
          final chapter = _requiredXmlInt(
            chapterElement,
            'number',
            '$bookPath[$bookId]/chapter',
            alternatives: const ['cnumber'],
          );
          final verses = chapterElement.childElements.where(
            (element) => element.name.local.toLowerCase() == 'verse',
          );
          for (final verseElement in verses) {
            final verse = _requiredXmlInt(
              verseElement,
              'number',
              '$bookPath[$bookId]/chapter[$chapter]/verse',
              alternatives: const ['vnumber'],
            );
            final translatedTestament = testamentName?.isNotEmpty == true
                ? testamentName!
                : bookId <= 39
                ? metadata.oldTestamentName
                : metadata.newTestamentName;
            versions.add(
              Version(
                id: versions.length,
                chapter: chapter,
                verse: verse,
                text: _verseText(
                  verseElement,
                  '$bookPath[$bookId]/chapter[$chapter]/verse[$verse]',
                ),
                translationId: metadata.translationId,
                bookId: bookId,
                bookName: bookName,
                testament: translatedTestament,
              ),
            );
          }
        }
      }
    }

    if (missingBookIds.isNotEmpty) {
      throw MissingScriptureDataException(missingBookIds.toList()..sort());
    }

    return _scripture(metadata, versions);
  }
}

class ScriptureImportMetadata {
  const ScriptureImportMetadata({
    required this.id,
    required this.versionName,
    required this.languageCode,
    required this.languageName,
    required this.dialect,
    required this.translationId,
    required this.oldTestamentName,
    required this.newTestamentName,
    this.bookNames = const {},
    this.languageCatalogBookNames = const {},
    this.languageCatalogMatchesNumbered66BookCanon = false,
  });

  ScriptureImportMetadata copyWithBookNames(Map<int, String> bookNames) =>
      ScriptureImportMetadata(
        id: id,
        versionName: versionName,
        languageCode: languageCode,
        languageName: languageName,
        dialect: dialect,
        translationId: translationId,
        oldTestamentName: oldTestamentName,
        newTestamentName: newTestamentName,
        bookNames: bookNames,
        languageCatalogBookNames: languageCatalogBookNames,
        languageCatalogMatchesNumbered66BookCanon:
            languageCatalogMatchesNumbered66BookCanon,
      );

  ScriptureImportMetadata copyWithLanguageCatalog(LanguageCatalog catalog) =>
      ScriptureImportMetadata(
        id: id,
        versionName: versionName,
        languageCode: languageCode,
        languageName: languageName,
        dialect: dialect,
        translationId: translationId,
        oldTestamentName: oldTestamentName,
        newTestamentName: newTestamentName,
        bookNames: bookNames,
        languageCatalogBookNames: catalog.bookNames,
        languageCatalogMatchesNumbered66BookCanon:
            catalog.supportsNumbered66BookCanon,
      );

  final String id;
  final String versionName;
  final String languageCode;
  final String languageName;
  final String dialect;
  final String translationId;
  final String oldTestamentName;
  final String newTestamentName;
  final Map<int, String> bookNames;
  final Map<int, String> languageCatalogBookNames;
  final bool languageCatalogMatchesNumbered66BookCanon;
}

bool _matchesNumbered66BookCanon(
  List<List<XmlElement>> booksByTestament,
  List<int> bookIds,
  Map<int, String> catalog,
  bool catalogMatchesCanon,
) {
  if (!catalogMatchesCanon ||
      booksByTestament.length != 2 ||
      booksByTestament[0].length != 39 ||
      booksByTestament[1].length != 27 ||
      catalog.length != 66 ||
      bookIds.length != 66 ||
      bookIds.toSet().length != 66) {
    return false;
  }
  if (!List.generate(66, (index) => index + 1).every(catalog.containsKey)) {
    return false;
  }
  final oldTestamentIds = bookIds.take(39).toSet();
  final newTestamentIds = bookIds.skip(39).toSet();
  return List.generate(
        39,
        (index) => index + 1,
      ).every(oldTestamentIds.contains) &&
      List.generate(27, (index) => index + 40).every(newTestamentIds.contains);
}

class MissingScriptureDataException implements Exception {
  const MissingScriptureDataException(this.bookIds);

  final List<int> bookIds;
}

Scripture _scripture(ScriptureImportMetadata metadata, List<Version> versions) {
  if (versions.isEmpty) {
    throw const FormatException('No verses found.');
  }
  return Scripture(
    id: metadata.id,
    versionName: metadata.versionName,
    language: Language(
      code: metadata.languageCode,
      name: metadata.languageName,
      dialect: metadata.dialect,
    ),
    version: versions,
  );
}

String _requiredXmlString(XmlElement element, String attribute, String path) {
  final value = element.getAttribute(attribute)?.trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing "$attribute" attribute at $path.');
  }
  return value;
}

int _requiredXmlInt(
  XmlElement element,
  String attribute,
  String path, {
  List<String> alternatives = const [],
}) {
  final value = _optionalXmlString(element, [attribute, ...alternatives]);
  if (value == null) {
    throw FormatException(
      'Missing "$attribute" attribute at $path'
      '${alternatives.isEmpty ? '' : ' (also tried ${alternatives.join(', ')})'}.',
    );
  }
  final parsed = int.tryParse(value);
  if (parsed == null) {
    throw FormatException(
      'Expected an integer in "$attribute" at $path, got "$value".',
    );
  }
  return parsed;
}

String? _optionalXmlString(XmlElement element, List<String> attributes) {
  for (final attribute in attributes) {
    final value = element.getAttribute(attribute)?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String _verseText(XmlElement element, String path) {
  final text = element.innerText.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) {
    throw FormatException('Empty verse text at $path.');
  }
  return text;
}
