# Gruvbox-Plus-Dark-IceBlue-FullBlue

Bifrost distributes the user-selected FullBlue SVG snapshot captured on
2026-09-26. This is a modified Gruvbox Plus theme: cold blue application and
file icons, icy folders and blue folder symbols. SVG contents are unchanged
from that snapshot. Identical files are stored as archive hard links to avoid
duplicating the same source hundreds of thousands of times. The archive
contains editable SVG source, index.theme, LICENSE and Licenses.

Upstream: https://github.com/SylEleuth/gruvbox-plus-icon-pack
Gruvbox Plus by Sylwia Ptasinska, GPL-3.0. Original icon attributions and
copyright notices remain in index.theme and individual SVGs. Additional
attributions are in Licenses. License/attribution files retrieved from upstream
commit 4871affc1679ed91f541061afb2e5e96a1027fe4; this identifies those documents,
not an asserted upstream base revision for the custom artwork.

`manifest.json` pins the archive SHA-256, file count and complete content-list
hash. Installation uses only this bundle, needs no existing Gruvbox theme or
network, verifies the checksum, extracts with Python's safe data filter and
builds the GTK icon cache when gtk-update-icon-cache is available.
Existing installations of this exact theme are preserved.
