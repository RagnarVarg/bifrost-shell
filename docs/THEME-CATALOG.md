# Theme browser

The first catalog adapter uses Tinted Theming Base16:
https://github.com/tinted-theming/schemes (spec-0.11 branch).
351 valid palette themes were fetched on 2026-09-26. The DMS registry contained
44 entries at review; Tinted offers broader palette coverage and no shell runtime
dependency. This is a Bifrost palette conversion, not a DMS architecture port.

`bifrostctl themes browse [--refresh] --json` fetches/caches a normalized catalog
under the Bifrost config directory (`catalogs/tinted.json`). Format version 1:
`format, version, source, license, themes[]`. Each theme has id, name, author,
SHA-256 content version, description, variant, palette, source and compatibility.
Palettes are also the previews; Bifrost retains materials, icons and typography.

`themes install ID` installs/updates a validated JSON theme under `themes/`.
`themes remove ID` refuses the active theme and files not owned by this catalog.
Settings Apply selects the theme and its supported light/dark mode. File watching
reloads the active user theme after updates, without restarting shell or Settings.

Security: HTTPS to a fixed source, bounded download, timeout, no archive extraction,
no scripts/hooks, strict Base16 color validation, restricted IDs, no foreign-file
replacement, and symlink rejection for install targets. Only generated data is
installed. Each installed JSON retains author, source and upstream MIT license.
No uploaded code runs. Remote content cannot set arbitrary Bifrost config keys.

Offline: cached entries remain available; installed themes do not need the catalog.
A failed refresh reports offline and leaves the last valid catalog intact.
