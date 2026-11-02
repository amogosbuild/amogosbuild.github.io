# Use real APT against a loopback-only archive and reject a deliberately corrupted download.
import functools
import http.server
import json
import pathlib
import subprocess
import sys
import tempfile
import threading

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from archive import ROOT, sha256

manifest = json.loads((ROOT / "repository.json").read_text())
updater = next(item for item in manifest["packages"] if item["package"] == "amogos-update" and item["version"] == "2.1.0-1")
requests = []
tamper = False
previous_release = True
old_release = (ROOT/'tests/fixtures/amogos-2.0.InRelease').read_bytes()


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *arguments):
        pass

    def do_GET(self):
        requests.append(self.path)
        if self.path.endswith('/InRelease'):
            body=old_release if previous_release else (ROOT/'dists/stable/InRelease').read_bytes()
            self.send_response(200)
            self.send_header('Content-Length',str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif tamper and self.path.endswith(".deb"):
            body = b"corrupted test download"
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(ROOT)))
worker = threading.Thread(target=server.serve_forever, daemon=True)
worker.start()
try:
    with tempfile.TemporaryDirectory(prefix="amogos-apt-test-") as temporary:
        temporary = pathlib.Path(temporary)
        temporary.chmod(0o755)
        for folder in ("etc/parts", "etc/sources.list.d", "etc/preferences.d", "state/lists/partial", "cache/archives/partial", "log", "downloads"):
            (temporary / folder).mkdir(parents=True, exist_ok=True)
        (temporary / "downloads").chmod(0o777)
        source = "deb [arch=amd64 signed-by=" + str(ROOT / "keyrings/amogos-archive-keyring.gpg") + "] http://127.0.0.1:" + str(server.server_port) + " stable main\n"
        (temporary / "etc/sources.list").write_text(source)
        status = pathlib.Path("/var/lib/dpkg/status").read_text()
        status = "\n\n".join(p for p in status.split("\n\n") if not p.startswith("Package: amogos-update\n"))
        for name in ("amogos-system", "amogos-store", "qtwayland5", "qt6-wayland", "xwayland", "xauth", "libxcb-cursor0", "python3-apt"):
            status = "\n\n".join(p for p in status.split("\n\n") if not p.startswith("Package: " + name + "\n"))
            status += "\n\nPackage: " + name + "\nStatus: install ok installed\nArchitecture: all\nVersion: 9999\nMaintainer: Test\nDescription: Dependency fixture\n\n"
        status += "\n\nPackage: amogos-update\nStatus: install ok installed\nArchitecture: all\nVersion: 2.0.0-0\nMaintainer: Test\nDescription: Older installed fixture\n\n"
        (temporary / "state/status").write_text(status)
        configuration = temporary / "apt.conf"
        configuration.write_text('Dir::Etc "' + str(temporary / "etc") + '";\nDir::Etc::main "/dev/null";\nDir::Etc::parts "parts";\nDir::Etc::sourcelist "sources.list";\nDir::State "' + str(temporary / "state") + '";\nDir::State::status "status";\nDir::State::lists "lists";\nDir::Cache "' + str(temporary / "cache") + '";\nDir::Log "' + str(temporary / "log") + '";\nAPT::Architecture "amd64";\nAPT::Architectures { "amd64"; };\nAcquire::Languages "none";\n#clear APT::Update::Pre-Invoke;\n#clear APT::Update::Post-Invoke;\n#clear APT::Update::Post-Invoke-Success;\n#clear DPkg::Post-Invoke;\n')
        def apt(*arguments, success=True):
            result = subprocess.run(["apt-get", "-c", str(configuration), *arguments], cwd=temporary / "downloads", text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            if (result.returncode == 0) != success:
                raise RuntimeError(result.stdout)
            return result.stdout
        apt("-o", "APT::Update::Error-Mode=any", "update")
        previous_release = False
        apt("-o", "APT::Update::Error-Mode=any", "update")
        if not any("/by-hash/" in request for request in requests):
            raise RuntimeError("APT did not fetch an immutable index")
        plan = apt("--simulate", "--only-upgrade", "install", "amogos-update")
        if "Inst amogos-update" not in plan or updater["version"] not in plan:
            raise RuntimeError("APT did not detect the updater upgrade: " + plan)
        apt("download", "amogos-update")
        downloaded = next((temporary / "downloads").glob("*.deb"))
        if sha256(downloaded) != updater["sha256"]:
            raise RuntimeError("The authenticated download is incorrect")
        downloaded.unlink()
        tamper = True
        error = apt("download", "amogos-update", success=False)
        if not any(word in error.lower() for word in ("hash", "size", "unexpected")):
            raise RuntimeError("The corrupted download failed for an unrelated reason: " + error)
        print(json.dumps(dict(passed=True, signedAptUpdate=True, byHash=True, updaterUpgradeDetected=True, authenticatedDownload=True, corruptedDownloadRejected=True), indent=2))
finally:
    server.shutdown()
    server.server_close()
    worker.join(timeout=5)
