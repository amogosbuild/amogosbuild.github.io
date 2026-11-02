# App Store architecture

The Flutter desktop interface runs as the logged-in user. Catalog lookups and
AppImage integration run through the unprivileged Python dispatcher. A fixed
polkit helper handles APT and system Flatpak transactions after authentication.
The helper accepts named JSON actions; it never accepts an arbitrary command.

## Folders

- lib/app/: app ownership, Material 3 black and light themes.
- lib/core/: catalog models, helper transport, controller, and queue.
- lib/features/: browsing, app details, source choices, updates, sources, queue.
- backend/amogos_store/: independent catalog and transaction implementations.
- packaging/: Debian package metadata, desktop launcher, fixed helper, polkit.
- assets/characters/: all seven original shopper PNGs supplied by the user.
- assets/catalog/: bundled icons, featured image, and Windows preview snapshot.
- scripts/: builds, comment audit, integration tests, and ISO verification.
- test/ and backend/tests/: interface, queue, and backend boundary tests.

## Available formats

App details show a single Install from dropdown with APT, Flatpak, and AppImage.
Only formats backed by a matching catalog entry are included. APT repository
choices are a separate field and retain their specific available versions.
AppImage choices are filtered for compatible x86-64 AppImage downloads.

APT reads python3-apt and the system's signed repository indexes. AppStream adds
application names and categories. Flathub supplies current app metadata, while
both user and system Flatpak installations supply actual installed state. AppImageHub
uses the shared openDesktop OCS API and its application categories.

Flatpak is optional. Its absence is reported explicitly, the app's Flatpak
install action stays disabled, and Install Flatpak reviews an APT installation.
Flathub can then be enabled in Sources. The ISO includes Flatpak by default.

MCPI Reborn uses the documented Flathub application com.thebrokenrail.MCPIReborn.
The Essentials card is labelled MCP Revived to match the supplied mockup, and
Latest upstream release links to the publisher's releases/latest endpoint.
No release tag is pinned in the implementation.

## Queue and system updates

The sidebar queue button sits above the theme control. It shows the active job,
progress, waiting jobs, completion, and copyable error logs. Jobs execute
serially. Waiting entries can be removed without interrupting package managers.

Before a queued privileged job starts, a fresh plan is resolved. APT may omit
dependencies already satisfied by a previous queue item. New or changed package
actions require another review. Backend tokens are owner-bound, expire after
15 minutes, are single use, and are checked against current installed state.
Untrusted APT origins, essential-system removals, and downgrades are refused.
The normal APT and Flatpak locks still protect their package databases.

Installed reads the complete local APT inventory, system/user Flatpak apps and
runtimes, and managed AppImage receipts without requiring an online catalog.
The combined inventory is searchable, filtered by format, and paginated.

Updates has independent APT, Flatpak and AppImage sections. Users select each
package or Select all within one format before reviewing. Selected APT updates
use the dependency resolver without requesting a distribution-wide upgrade;
the complete APT system upgrade remains available as a separate action.
Flatpak selections preserve each scope, origin, full reference and exact commit.
User Flatpak reviews and application run entirely in the desktop account, with
private single-use tokens. System Flatpaks still use the authenticated helper.
The queue refuses changes to reviewed origins or commits. AppImage updates keep
the selected publisher build and are applied separately through the user queue.
Failures in one update source leave the other sources available. Kernel and
NVIDIA module updates set a restart-required marker.

Compact windows use a scrolling drawer, toolbar search and queue access, adaptive
grids and wrapping dialog actions. The rose sidebar and its animated selection
dot remain available inside the drawer.

AppImages are downloaded and integrated only as the current user. Download
redirects must use public HTTPS; files are checked for the AppImage ELF marker
and x86-64 machine type, and a publisher MD5 is checked when available. A local
SHA-256 receipt is recorded. Removal preserves application data. AppImages are
never downloaded or launched through the root helper.

APT browsing pages through the complete configured package cache, including
command-line tools and libraries. Featured picks affect ordering only. Repository
filters include packages whose matching version is not APT's default candidate.
Search covers package names, summaries, AppStream names, and long descriptions.

AppImage binaries and desktop launchers receive executable permissions. Menu
categories come from the AppImageHub application taxonomy, mapped to registered
desktop categories. Existing receipts are repaired using cached metadata, without
requiring another download. A dedicated unprivileged launcher handles both the
Store's Open action and menu launches; it isolates session Qt plugin paths,
supports the runtime's FUSE extraction fallback, and records launch errors. An
early failure is shown in the Store or a desktop error dialog instead of being
reported as a successful launch.

## Artwork and navigation

The selected navigation text uses weight 800. A translucent dot behind it moves
with a 380 ms eased animation. The common header shopper follows the theme.
Per launch, the rare shopper has a 2% chance and the semi-rare shopper an 8%
chance; selection stays stable throughout the session. Wide, silly, and ripped
bag shoppers are used in browsing, empty/up-to-date, and failed-queue states.

Every maintained source file has exactly one comment. The audit normalizes
Flutter's generated native template comments after builds; third-party licenses
remain in third_party/.
