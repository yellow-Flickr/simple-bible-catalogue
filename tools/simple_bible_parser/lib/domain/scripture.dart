import 'dart:convert';

class Scripture {
  final String id;
  final String versionName;
  final Language language;
  final List<Version> version;

  Scripture({
    required this.id,
    required this.versionName,
    required this.language,
    required this.version,
  });

  Scripture copyWith({
    String? id,
    String? versionName,
    Language? language,
    List<Version>? version,
  }) => Scripture(
    id: id ?? this.id,
    versionName: versionName ?? this.versionName,
    language: language ?? this.language,
    version: version ?? this.version,
  );

  factory Scripture.fromRawJson(String str) =>
      Scripture.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Scripture.fromJson(Map<String, dynamic> json) => Scripture(
    id: json["id"],
    versionName: json["version_name"],
    language: Language.fromJson(json["language"]),
    version: List<Version>.from(
      json["version"].map((x) => Version.fromJson(x)),
    ),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "version_name": versionName,
    "language": language.toJson(),
    "version": List<dynamic>.from(version.map((x) => x.toJson())),
  };
}

class Language {
  final String code;
  final String name;
  final String dialect;

  Language({required this.code, required this.name, required this.dialect});

  Language copyWith({String? code, String? name, String? dialect}) => Language(
    code: code ?? this.code,
    name: name ?? this.name,
    dialect: dialect ?? this.dialect,
  );

  factory Language.fromRawJson(String str) =>
      Language.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Language.fromJson(Map<String, dynamic> json) => Language(
    code: json["code"],
    name: json["name"],
    dialect: json["dialect"],
  );

  Map<String, dynamic> toJson() => {
    "code": code,
    "name": name,
    "dialect": dialect,
  };
}

class Version {
  final int id;
  final int chapter;
  final int verse;
  final String text;
  final String translationId;
  final int bookId;
  final String bookName;
  final String testament;

  Version({
    required this.id,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.translationId,
    required this.bookId,
    required this.bookName,
    required this.testament,
  });

  Version copyWith({
    int? id,
    int? chapter,
    int? verse,
    String? text,
    String? translationId,
    int? bookId,
    String? bookName,
    String? testament,
  }) => Version(
    id: id ?? this.id,
    chapter: chapter ?? this.chapter,
    verse: verse ?? this.verse,
    text: text ?? this.text,
    translationId: translationId ?? this.translationId,
    bookId: bookId ?? this.bookId,
    bookName: bookName ?? this.bookName,
    testament: testament ?? this.testament,
  );

  factory Version.fromRawJson(String str) => Version.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Version.fromJson(Map<String, dynamic> json) => Version(
    id: json["id"],
    chapter: json["chapter"],
    verse: json["verse"],
    text: json["text"],
    translationId: json["translation_id"],
    bookId: json["book_id"],
    bookName: json["book_name"],
    testament: json["testament"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "chapter": chapter,
    "verse": verse,
    "text": text,
    "translation_id": translationId,
    "book_id": bookId,
    "book_name": bookName,
    "testament": testament,
  };
}
