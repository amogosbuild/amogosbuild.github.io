# Render human-readable package downloads directly from the authenticated archive manifest.
import html
import json
from urllib.parse import quote
from archive import ROOT, write

manifest = json.loads((ROOT / "repository.json").read_text())
commands = {"amogos-installer": "amogos-installer", "amogos-store": "amogos-appstore", "amogos-music": "amogos-music", "amogos-notes": "amogos-notes", "amogos-update": "amogos-update", "amogos-system": "Persistent boot theme and system policy", "amogos-archive-keyring": "APT signing key and source"}
rows, markdown = [], ["# Available packages", "", "Generated from the archive metadata. All application DEBs target Debian 13 amd64.", "", "| Package | Version | Architecture | Command or purpose | Download |", "| --- | --- | --- | --- | --- |"]
for package in manifest["packages"]:
    name, version, architecture = package["package"], package["version"], package["architecture"]
    path = quote(package["filename"], safe="/")
    command = commands.get(name, name)
    rows.append("<tr><th scope=\"row\">" + html.escape(name) + "</th><td>" + html.escape(version) + "</td><td>" + html.escape(architecture) + "</td><td>" + html.escape(command) + "</td><td><a href=\"" + path + "\">DEB · " + str(round(package["bytes"] / 1048576, 1)) + " MB</a></td></tr>")
    markdown.append("| " + name + " | " + version + " | " + architecture + " | " + command + " | [DEB](" + package["filename"] + ") |")
write(ROOT / "PACKAGES.md", "\n".join(markdown) + "\n")
page = """<!doctype html>
<!-- Public package catalog generated from repository.json. -->
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="Signed AmogOS 2 Pro application packages and system update migrations for Debian 13.">
<title>AmogOS 2 Pro · Debian repository</title>
<style>
:root{color-scheme:light dark;font-family:system-ui,sans-serif;background:#f7f3fc;color:#251d31}
body{max-width:1100px;margin:auto;padding:36px 24px 60px;line-height:1.6}a{color:#7042ba}header{padding:36px;border:1px solid #ddcdec;border-radius:24px;background:linear-gradient(125deg,#fde9f3,#ece7fc)}h1{font-size:clamp(2rem,5vw,3rem);line-height:1.15;margin:10px 0 16px}h2{margin-top:32px;font-size:1.4rem}.eyebrow{font-weight:700;letter-spacing:.12em;font-size:.8rem;text-transform:uppercase}nav{display:flex;gap:18px;flex-wrap:wrap}pre{padding:20px;background:#eee7f5;border-radius:14px;overflow:auto}code{font-size:.9rem}.table-wrap{overflow:auto;border:1px solid #ddcdec;border-radius:16px}table{width:100%;border-collapse:collapse;text-align:left;font-size:.92rem}th,td{padding:14px;border-bottom:1px solid #ddcdec}tbody th{font-weight:600}footer{margin-top:36px;color:#6b5b7c;font-size:.9rem}.fingerprint{overflow-wrap:anywhere}
@media(prefers-color-scheme:dark){:root{background:#08060c;color:#eee7f7}header{background:linear-gradient(125deg,#28131f,#20152f)}a{color:#d1aeff}pre{background:#20152b}header,.table-wrap,th,td{border-color:#3d2b4d}footer{color:#beadc9}}
</style>
</head>
<body>
<header><div class="eyebrow">AmogOS 2 Pro · stable</div><h1>Your AmogOS apps.<br>One signed repository.</h1><p>Installer, App Store, Music and Notes for Debian 13 amd64, plus the AmogOS system update package.</p><nav aria-label="Repository links"><a href="#setup">Set up APT</a><a href="#packages">Download packages</a><a href="https://github.com/amogosbuild/amogosbuild.github.io/tree/main/amogos-debian">Source and maintenance guide</a><a href="https://github.com/amogosbuild/AmogOS-2.x-Builder">Build the ISO</a></nav></header>
<main>
<section id="setup"><h2>Set up the repository</h2><p>Download and review the setup script, then run it as root. It verifies the keyring package checksum, configures the scoped signing key and refreshes APT.</p><pre><code>curl --fail --location --output install.sh \\
  https://amogosbuild.github.io/amogos-debian/install.sh
less install.sh
sudo sh install.sh</code></pre><p>Then install an app, for example:</p><pre><code>sudo apt install amogos-notes amogos-music amogos-store</code></pre><p>The repository adds AmogOS packages alongside your Debian repositories. The installer is available as <code>amogos-installer</code> for live installation media.</p></section>
<section id="packages"><h2>Available packages</h2><div class="table-wrap"><table><thead><tr><th scope="col">Package</th><th scope="col">Version</th><th scope="col">Architecture</th><th scope="col">Command or purpose</th><th scope="col">Download</th></tr></thead><tbody>@ROWS@</tbody></table></div><p>APT verifies signed indexes and package checksums. <a href="SHA256SUMS">SHA-256 checksums</a> are also available for direct downloads.</p></section>
<section><h2>System update migrations</h2><p>The 2.1 update repairs Debian package support, upgrades the App Store and removes live installers from installed systems. Systems already on 2.1 or newer report that they are up to date. When a newer package version is installed during an OS update, its new script runs automatically. Successful versions are recorded so reinstalls do not repeat them; failed migrations remain pending.</p></section>
<section><h2>Archive signing key</h2><p class="fingerprint"><code>@FINGERPRINT@</code></p><p><a href="keyrings/amogos-archive-keyring.asc">Public key</a> · <a href="dists/stable/InRelease">Signed Release</a> · <a href="repository.json">Package metadata</a></p></section>
</main><footer>The Arch project remains reserved for future work. These packages target AmogOS 2 Pro and Debian 13 amd64.</footer>
</body>
</html>
"""
write(ROOT / "index.html", page.replace("@ROWS@", "".join(rows)).replace("@FINGERPRINT@", html.escape(manifest["signingFingerprint"])))
write(ROOT.parent / "index.html", '<!doctype html>\n<!-- Direct repository visitors to the generated Debian package catalog. -->\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="refresh" content="0;url=amogos-debian/"><title>AmogOS repositories</title></head><body><h1>AmogOS 2 Pro</h1><p><a href="amogos-debian/">Open the Debian package repository</a></p></body></html>\n')
print("Generated package catalog for", len(manifest["packages"]), "packages")
