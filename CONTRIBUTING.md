# Contributing

Contributions to the catalogue, version data, schemas, and parser are welcome.
For changes intended to support the in-app **More Versions** experience, keep
the catalogue and downloadable files consistent.

## Before adding Bible text

- Confirm that the exact translation/edition may be redistributed in the app.
- Check the upstream file and translation-specific rights; a public repository
  or a statement that data is open does not necessarily grant permission to
  redistribute every included text.
- Preserve required copyright notices and attribution.
- Record the upstream repository and, where possible, the exact source file or
  edition in [`ATTRIBUTION.md`](ATTRIBUTION.md).
- Do not add a version if its redistribution terms or required credit are
  unknown.

## Version data and catalogue entries

1. Store the version JSON under `versions/`, using a stable descriptive path.
   The file must match [`schema/version.schema.json`](schema/version.schema.json).
2. Add one entry to [`catalogue.json`](catalogue.json) that describes the file.
   The entry must match [`schema/catalogue.schema.json`](schema/catalogue.schema.json).
3. Use a unique `id` and an accurate display name, abbreviation, and language.
   `translationId` identifies the main translation label; use `translationIds`
   when one data file contains multiple translation IDs.
4. Set `url` to a repository-root-relative path ending in `.json`. Ensure the
   path resolves from the repository's raw GitHub base URL.
5. Set `sizeBytes` to the exact size of the committed file, `bookCount` to the
   number of distinct book IDs, and `verseCount` to the number of verse records.
   Ensure the version file's top-level `id` matches the catalogue entry.
6. Use a new version path/revision for changed data instead of silently
   replacing a file clients may already have downloaded.
7. Update `updatedAt` when the catalogue changes.

The `tools/simple_bible_parser/` directory contains a Dart parser and its
instructions. From that directory, run:

```sh
dart test
dart analyze
```

Before submitting, validate changed JSON against both schemas, verify that each
changed catalogue URL points to a file in the repository, and check its byte
size and counts against the catalogue metadata. Keep changes focused and
include a short description of the source and validation performed.

## Pull requests

Please include:

- which catalogue entries or schemas changed;
- the source and rights/attribution information for added or updated text; and
- the validation performed.
