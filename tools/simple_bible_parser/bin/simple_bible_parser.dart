import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:simple_bible_parser/simple_bible_parser.dart';

Future<void> main(List<String> arguments) async {
  try {
    final inputPath = arguments.isEmpty
        ? _ask('Input file path')
        : arguments[0];
    if (arguments.length > 2) {
      stderr.writeln(
        'Usage: dart run bin/simple_bible_parser.dart [input] [output]',
      );
      exitCode = 64;
      return;
    }

    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Input file does not exist', inputPath);
    }
    final extension = path.extension(inputPath).toLowerCase();
    final source = await inputFile.readAsString();
    final importer = ScriptureImporter();
    final Scripture scripture;

    if (extension == '.json') {
      scripture = importer.fromJson(source);
    } else if (extension == '.xml') {
      final defaults = _metadataDefaults(inputPath);
      final catalogs = await LanguageCatalogRepository(
        Directory('assets/languages'),
      ).loadAll();
      final catalog = _selectLanguageCatalog(catalogs);
      if (catalog != null && !catalog.supportsNumbered66BookCanon) {
        stdout.writeln(
          'This catalog is not a complete numbered 66-book Protestant canon; '
          'book names may need to be entered manually.',
        );
      }
      final metadata = ScriptureImportMetadata(
        id: _ask('Scripture id', defaultValue: defaults.id),
        versionName: _ask('Version name', defaultValue: defaults.versionName),
        languageCode: _ask('Language code', defaultValue: catalog?.code ?? ''),
        languageName: _ask('Language name', defaultValue: catalog?.name ?? ''),
        dialect: _ask(
          'Language dialect (optional)',
          defaultValue: catalog?.dialect ?? '',
        ),
        translationId: _ask(
          'Translation id',
          defaultValue: defaults.translationId,
        ),
        oldTestamentName: _ask(
          'Old testament label',
          defaultValue: 'Old Testament',
        ),
        newTestamentName: _ask(
          'New testament label',
          defaultValue: 'New Testament',
        ),
        languageCatalogBookNames: catalog?.bookNames ?? const {},
        languageCatalogMatchesNumbered66BookCanon:
            catalog?.supportsNumbered66BookCanon ?? false,
      );
      scripture = _parseXmlWithPrompts(importer, source, metadata);
    } else {
      throw FormatException(
        'Unsupported input extension "$extension". Choose a .json or .xml file.',
      );
    }

    stdout
      ..writeln('Parsed ${scripture.version.length} verses.')
      ..writeln(
        'First verse: ${scripture.version.first.bookName} '
        '${scripture.version.first.chapter}:${scripture.version.first.verse} '
        '${scripture.version.first.text}',
      );
    if (_ask(
      'Write this parsed result? [Y/n]',
      defaultValue: 'y',
    ).toLowerCase().startsWith('n')) {
      stdout.writeln(
        'Not written. Add or adjust a source parser and try again if the '
        'parsed structure is incorrect.',
      );
      return;
    }

    final outputPath = arguments.length == 2
        ? arguments[1]
        : path.join(
            'assets',
            'outputs',
            '${path.basenameWithoutExtension(inputPath)}.json',
          );
    if (path.normalize(path.absolute(outputPath)) ==
        path.normalize(path.absolute(inputPath))) {
      throw StateError('Input and output paths must be different.');
    }
    if (await FileSystemEntity.type(outputPath) ==
        FileSystemEntityType.directory) {
      throw StateError(
        'Output path "$outputPath" is a directory. Choose a JSON file path.',
      );
    }
    final outputFile = File(outputPath);
    if (await outputFile.exists() &&
        _ask(
          'Output exists. Overwrite it? [y/N]',
          defaultValue: 'n',
        ).toLowerCase().startsWith('n')) {
      stdout.writeln('Cancelled; existing output was left unchanged.');
      return;
    }

    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(scripture.toJson()),
      flush: true,
    );
    stdout.writeln('Wrote ${scripture.version.length} verses to $outputPath');
  } on FormatException catch (error) {
    stderr.writeln('Import failed: ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('File error: $error');
    exitCode = 1;
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

LanguageCatalog? _selectLanguageCatalog(List<LanguageCatalog> catalogs) {
  if (catalogs.isEmpty) {
    stdout.writeln(
      'No language catalogs found in assets/languages; book names will be '
      'requested manually when missing.',
    );
    return null;
  }

  stdout.writeln('Available book-name language catalogs:');
  for (var index = 0; index < catalogs.length; index++) {
    final catalog = catalogs[index];
    final dialect = catalog.dialect.isEmpty ? '' : ' (${catalog.dialect})';
    stdout.writeln(
      '  ${index + 1}. ${catalog.name}$dialect '
      '[${catalog.code}; ${catalog.bookNames.length} book names]',
    );
  }
  stdout.writeln('  0. Enter missing book names manually');

  while (true) {
    final selection = _ask('Select a catalog', defaultValue: '0');
    final index = int.tryParse(selection);
    if (index != null && index >= 0 && index <= catalogs.length) {
      return index == 0 ? null : catalogs[index - 1];
    }
    stderr.writeln('Choose a number from 0 to ${catalogs.length}.');
  }
}

String _ask(String prompt, {String defaultValue = ''}) {
  while (true) {
    final suffix = defaultValue.isEmpty ? '' : ' [$defaultValue]';
    stdout.write('$prompt$suffix: ');
    final input = stdin.readLineSync()?.trim();
    if (input == null) {
      throw StateError('No console input received while asking: $prompt');
    }
    if (input.isNotEmpty) return input;
    if (defaultValue.isNotEmpty) return defaultValue;
    if (prompt.contains('(optional)')) return '';
    stderr.writeln('A value is required.');
  }
}

Scripture _parseXmlWithPrompts(
  ScriptureImporter importer,
  String source,
  ScriptureImportMetadata metadata,
) {
  var currentMetadata = metadata;
  while (true) {
    try {
      return importer.fromXml(source, metadata: currentMetadata);
    } on MissingScriptureDataException catch (error) {
      final bookNames = Map<int, String>.of(currentMetadata.bookNames);
      for (final bookId in error.bookIds) {
        bookNames[bookId] = _ask('Name for book $bookId');
      }
      currentMetadata = currentMetadata.copyWithBookNames(bookNames);
    }
  }
}

({String id, String versionName, String translationId}) _metadataDefaults(
  String inputPath,
) {
  final versionName = path.basenameWithoutExtension(inputPath);
  final id = versionName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return (
    id: id,
    versionName: versionName,
    translationId: id.toUpperCase().replaceAll('-', ''),
  );
}
