# Simple Bible Catalogue

This repository provides the version catalogue and downloadable Bible data for
the **More Versions** feature in [Simple Bible](https://github.com/yellow-Flickr/simple_bible).
The app reads [`catalogue.json`](catalogue.json) to discover available
translations; each catalogue entry points to a JSON data file in this repository.

## Catalogue endpoint

The raw catalogue URL for the `main` branch is:

```text
https://raw.githubusercontent.com/yellow-Flickr/simple-bible-catalogue/main/catalogue.json
```

Version `url` values are paths relative to the repository root. For example,
`versions/eng-amp.v1.json` is available at:

```text
https://raw.githubusercontent.com/yellow-Flickr/simple-bible-catalogue/main/versions/eng-amp.v1.json
```

The catalogue and version file formats are documented by the
[catalogue schema](schema/catalogue.schema.json) and
[version schema](schema/version.schema.json), both JSON Schema Draft 2020-12.

## Repository layout

- `catalogue.json` — metadata used to list and locate downloadable versions.
- `versions/` — version data files in the format consumed by Simple Bible.
- `schema/` — JSON schemas for the catalogue and version files.
- `tools/simple_bible_parser/` — Dart command-line tool for converting supported
  XML Bible sources to the version JSON format.
- [`ATTRIBUTION.md`](ATTRIBUTION.md) — source repositories and attribution notes.

## Adding or updating a version

1. Confirm that the source text may be redistributed in this app and record its
   required attribution and license/usage terms. See
   [ATTRIBUTION.md](ATTRIBUTION.md).
2. Convert or prepare the data using the format in
   [version.schema.json](schema/version.schema.json). The parser's usage and
   supported input formats are documented in
   [tools/simple_bible_parser/README.md](tools/simple_bible_parser/README.md).
3. Add the JSON file under `versions/`. Use a stable, descriptive path and
   increment the revision when publishing a changed version at an existing
   path. Avoid replacing a published version in place when possible.
4. Add or update its entry in `catalogue.json`. Set `url` to the path relative
   to this repository's root, `sizeBytes` to the exact file size in bytes, and
   `bookCount` and `verseCount` to the data's actual counts.
5. Validate both JSON documents against their schemas, check that the catalogue
   path exists, and verify that the metadata matches the version file.
6. Update `updatedAt` when changing the catalogue and include the source and
   attribution information in [`ATTRIBUTION.md`](ATTRIBUTION.md).

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contribution checklist.

## Attribution and rights

Many Bible data files in this catalogue are sourced from or prepared using
community-maintained Bible repositories. Their maintainers and the original
translation rights holders should be credited as applicable. A source
repository's availability does not by itself establish permission to
redistribute every text it contains. Check the specific edition's rights and
preserve any required notices before adding it.

See [ATTRIBUTION.md](ATTRIBUTION.md) for known sources and the process for
recording future sources. This repository does not grant a blanket license to
the Bible texts it distributes; rights and terms are specific to each text.
