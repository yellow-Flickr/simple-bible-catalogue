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

1. Store the version JSON as `versions/<id>.v<revision>.json`. The file must
   match [`schema/version.schema.json`](schema/version.schema.json).
2. Add one entry to [`catalogue.json`](catalogue.json) that describes the file.
   The entry must match [`schema/catalogue.schema.json`](schema/catalogue.schema.json).
3. Give the version an `id` made of its ISO 639-3 language code, a hyphen, and
   the publisher's abbreviation in lowercase: `eng-kjv`, `twi-akna`. Leave out
   the dialect, which belongs in `language.dialect`. A different edition or
   translation gets a new id (`eng-kjv1611`); corrections to the same text keep
   the id and bump `revision`. An id is never renamed or reused, even after the
   version is removed: the app stores it with users' bookmarks and history.
   The app reads the language from `language`, never from the id.
4. Use an accurate display name, abbreviation, and language. `translationId`
   is the short label shown in the app and must equal every verse's
   `translation_id`.
5. Set `url` to a repository-root-relative path ending in `.json`. Ensure the
   path resolves from the repository's raw GitHub base URL.
6. Set `sizeBytes` to the exact size of the committed file, `bookCount` to the
   number of distinct book IDs, and `verseCount` to the number of verse records.
   Ensure the version file's top-level `id` matches the catalogue entry.
7. Use a new version path/revision for changed data instead of silently
   replacing a file clients may already have downloaded.
8. Update `updatedAt` when the catalogue changes.

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
