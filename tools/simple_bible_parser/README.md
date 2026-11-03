# Simple Bible Parser

Convert Bible source files to the flat JSON structure used by
`assets/outputs/twi-akuapem.vi.json`.

## Run

```sh
dart run bin/simple_bible_parser.dart path/to/input.xml [path/to/output.json]
```

The output defaults to `assets/outputs/<input-file-name>.json`. XML imports ask
for language and translation metadata that the source does not contain, then
show the verse count and first parsed verse for confirmation before writing.
An existing output file is never overwritten without confirmation.

Supported inputs:

- **XML:** XMLBIBLE documents containing `BIBLEBOOK`, `CHAPTER`, and `VERS`
  elements, and nested `root/bible/testament/book/chapter/verse` documents.
  XML parsers are registered in order; matching parsers are attempted and
  their errors are reported together if none can parse the document.
- **JSON:** JSON already using the output `Scripture` structure. Other JSON
  shapes are rejected with a field path so they are not silently misread.

The target model is in `lib/domain/scripture.dart`. To support another XML
layout, implement `XmlScriptureParser` and register it with
`ScriptureImporter(xmlParsers: [...])`. Parser order determines which successful
parser is selected first.

## Book-name catalogs

Language catalogs live in `assets/languages/*.json`. The CLI lists the
available catalogs for XML imports. Use [en.json](assets/languages/en.json) or
[tw-akuapem.json](assets/languages/tw-akuapem.json) as a complete example. A
catalog contains language metadata, a canon identifier, the Old Testament
book count, and a `books` object keyed by numbered book IDs.

Automatic book-name population is deliberately limited to a complete
`protestant-66` catalog and a source with exactly two testament sections
containing the numbered books 1–39 and 40–66 respectively. Otherwise, missing
book names are requested in the console. Add a language catalog by copying
`assets/languages/en.json`, translating the names, and retaining the book
numbers and canon metadata only when they apply to that language's book order.

## Verify

```sh
dart test
dart analyze
```
