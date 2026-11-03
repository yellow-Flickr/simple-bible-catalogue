import 'package:xml/xml.dart';
import 'package:simple_bible_parser/simple_bible_parser.dart';
import 'package:test/test.dart';

void main() {
  const metadata = ScriptureImportMetadata(
    id: 'test-bible',
    versionName: 'Test Bible',
    languageCode: 'en',
    languageName: 'English',
    dialect: '',
    translationId: 'TEST',
    oldTestamentName: 'Old Testament',
    newTestamentName: 'New Testament',
  );

  test('converts XMLBIBLE books, chapters and verses to the output model', () {
    const source = '''
<XMLBIBLE biblename="TEST">
  <BIBLEBOOK bnumber="1" bname="Genesis">
    <CHAPTER cnumber="1">
      <VERS vnumber="1"> In the beginning </VERS>
      <VERS vnumber="2">Second verse</VERS>
    </CHAPTER>
  </BIBLEBOOK>
  <BIBLEBOOK bnumber="40" bname="Matthew">
    <CHAPTER cnumber="1">
      <VERS vnumber="1">New testament verse</VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>
''';

    final result = ScriptureImporter().fromXml(source, metadata: metadata);

    expect(result.id, 'test-bible');
    expect(result.language.code, 'en');
    expect(result.version, hasLength(3));
    expect(result.version[0].id, 0);
    expect(result.version[0].text, 'In the beginning');
    expect(result.version[0].testament, 'Old Testament');
    expect(result.version[2].bookId, 40);
    expect(result.version[2].testament, 'New Testament');
  });

  test('imports JSON in the output model format', () {
    const source = '''
{
  "id": "test-bible",
  "version_name": "Test Bible",
  "language": {"code": "en", "name": "English", "dialect": ""},
  "version": [{
    "id": 0,
    "chapter": 1,
    "verse": 1,
    "text": "In the beginning",
    "translation_id": "TEST",
    "book_id": 1,
    "book_name": "Genesis",
    "testament": "Old Testament"
  }]
}
''';

    final result = ScriptureImporter().fromJson(source);

    expect(result.versionName, 'Test Bible');
    expect(result.version.single.text, 'In the beginning');
    expect(
      ScriptureImporter().fromJson(result.toRawJson()).version.single.text,
      'In the beginning',
    );
  });

  test('reports JSON that needs a different source parser', () {
    expect(
      () => ScriptureImporter().fromJson('{"books": []}'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('root.id'),
        ),
      ),
    );
  });

  test('rejects XML formats that are not XMLBIBLE', () {
    expect(
      () => ScriptureImporter().fromXml(
        '<bible><book /></bible>',
        metadata: metadata,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('No XML parser recognized'),
        ),
      ),
    );
  });

  test('tries the nested testament parser for its XML layout', () {
    const source = '''
<root>
  <bible name="Example">
    <testament name="First Testament">
      <book number="1" name="Genesis">
        <chapter number="1">
          <verse number="1">In the beginning</verse>
        </chapter>
      </book>
    </testament>
  </bible>
</root>
''';

    final result = ScriptureImporter().fromXml(source, metadata: metadata);

    expect(result.version.single.bookName, 'Genesis');
    expect(result.version.single.testament, 'First Testament');
    expect(result.version.single.text, 'In the beginning');
  });

  test('uses language catalog when source has the numbered 66-book canon', () {
    final catalogNames = {
      for (var bookId = 1; bookId <= 66; bookId++) bookId: 'Book $bookId',
    };
    final oldBooks = List.generate(
      39,
      (index) =>
          '''
      <book number="${index + 1}">
        <chapter number="1"><verse number="1">Old verse</verse></chapter>
      </book>''',
    ).join();
    final newBooks = List.generate(
      27,
      (index) =>
          '''
      <book number="${index + 40}">
        <chapter number="1"><verse number="1">New verse</verse></chapter>
      </book>''',
    ).join();
    final source =
        '''
<bible>
  <testament name="Old">$oldBooks</testament>
  <testament name="New">$newBooks</testament>
</bible>
''';

    final result = ScriptureImporter().fromXml(
      source,
      metadata: metadata.copyWithLanguageCatalog(
        LanguageCatalog(
          code: 'en',
          name: 'English',
          dialect: '',
          canon: 'protestant-66',
          oldTestamentBookCount: 39,
          bookNames: catalogNames,
        ),
      ),
    );

    expect(result.version, hasLength(66));
    expect(result.version.first.bookName, 'Book 1');
    expect(result.version.last.bookName, 'Book 66');
  });

  test('does not apply a catalog to a partial book list', () {
    const source = '''
<bible>
  <testament name="Old">
    <book number="1">
      <chapter number="1"><verse number="1">In the beginning</verse></chapter>
    </book>
  </testament>
</bible>
''';
    final catalogNames = {
      for (var bookId = 1; bookId <= 66; bookId++) bookId: 'Book $bookId',
    };

    expect(
      () => ScriptureImporter().fromXml(
        source,
        metadata: metadata.copyWithLanguageCatalog(
          LanguageCatalog(
            code: 'en',
            name: 'English',
            dialect: '',
            canon: 'protestant-66',
            oldTestamentBookCount: 39,
            bookNames: catalogNames,
          ),
        ),
      ),
      throwsA(
        isA<MissingScriptureDataException>().having(
          (error) => error.bookIds,
          'bookIds',
          [1],
        ),
      ),
    );
  });

  test('requests book names absent from the nested XML model', () {
    const source = '''
<root>
  <bible>
    <testament name="First Testament">
      <book number="1">
        <chapter number="1">
          <verse number="1">In the beginning</verse>
        </chapter>
      </book>
    </testament>
  </bible>
</root>
''';
    final importer = ScriptureImporter();

    expect(
      () => importer.fromXml(source, metadata: metadata),
      throwsA(
        isA<MissingScriptureDataException>().having(
          (error) => error.bookIds,
          'bookIds',
          [1],
        ),
      ),
    );

    final result = importer.fromXml(
      source,
      metadata: metadata.copyWithBookNames({1: 'Genesis'}),
    );
    expect(result.version.single.bookName, 'Genesis');
  });

  test('reports errors from every matching XML parser', () {
    final importer = ScriptureImporter(
      xmlParsers: const [
        _FailingXmlParser('first parser'),
        _FailingXmlParser('second parser'),
      ],
    );

    expect(
      () => importer.fromXml('<root />', metadata: metadata),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('first parser: first parser failure'),
            contains('second parser: second parser failure'),
          ),
        ),
      ),
    );
  });
}

class _FailingXmlParser implements XmlScriptureParser {
  const _FailingXmlParser(this.name);

  @override
  final String name;

  @override
  bool supports(XmlElement root) => true;

  @override
  Scripture parse(
    XmlElement root, {
    required ScriptureImportMetadata metadata,
  }) {
    throw FormatException('$name failure');
  }
}
