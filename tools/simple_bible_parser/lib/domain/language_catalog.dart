import 'dart:convert';

class LanguageCatalog {
  const LanguageCatalog({
    required this.code,
    required this.name,
    required this.dialect,
    required this.canon,
    required this.oldTestamentBookCount,
    required this.bookNames,
  });

  final String code;
  final String name;
  final String dialect;
  final String canon;
  final int oldTestamentBookCount;
  final Map<int, String> bookNames;

  factory LanguageCatalog.fromJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid language catalog JSON: ${error.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Language catalog must be a JSON object.');
    }

    final booksData = decoded['books'];
    if (booksData is! Map<String, dynamic>) {
      throw const FormatException(
        'Language catalog "books" must be an object.',
      );
    }

    final books = <int, String>{};
    for (final entry in booksData.entries) {
      final id = int.tryParse(entry.key);
      final name = entry.value;
      if (id == null || id < 1) {
        throw FormatException(
          'Invalid book number "${entry.key}" in language catalog.',
        );
      }
      if (name is! String || name.trim().isEmpty) {
        throw FormatException(
          'Book "$id" must have a non-empty name in language catalog.',
        );
      }
      if (books.containsKey(id)) {
        throw FormatException(
          'Duplicate book number "$id" in language catalog.',
        );
      }
      books[id] = name.trim();
    }

    final oldTestamentBookCount = decoded['old_testament_book_count'];
    if (oldTestamentBookCount is! int ||
        oldTestamentBookCount < 1 ||
        oldTestamentBookCount >= books.length) {
      throw const FormatException(
        'Language catalog "old_testament_book_count" must be a positive '
        'integer smaller than the number of books.',
      );
    }

    return LanguageCatalog(
      code: _requiredString(decoded, 'code'),
      name: _requiredString(decoded, 'name'),
      dialect: _optionalString(decoded, 'dialect'),
      canon: _requiredString(decoded, 'canon'),
      oldTestamentBookCount: oldTestamentBookCount,
      bookNames: Map.unmodifiable(books),
    );
  }

  bool get supportsNumbered66BookCanon {
    if (canon != 'protestant-66' ||
        oldTestamentBookCount != 39 ||
        bookNames.length != 66) {
      return false;
    }
    return List.generate(66, (index) => index + 1).every(bookNames.containsKey);
  }
}

String _requiredString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException(
      'Language catalog "$key" must be a non-empty string.',
    );
  }
  return value.trim();
}

String _optionalString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return '';
  if (value is! String) {
    throw FormatException('Language catalog "$key" must be a string.');
  }
  return value.trim();
}
