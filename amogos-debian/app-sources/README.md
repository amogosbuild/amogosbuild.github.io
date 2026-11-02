# AmogOS application sources

App Store 0.1.4 and Installer 0.1.5 are built with Flutter 3.47.6 on Debian 13 amd64. Each application keeps its Flutter interface, Linux helper, packaging, assets and tests in separate folders. Application IDs and terminal commands remain amogos.appstore / amogos-appstore and amogos.installer / amogos-installer.

Install the Flutter Linux build prerequisites (clang, cmake, ninja-build, pkg-config, libgtk-3-dev and the development libraries required by the plugins). Then, inside the desired app folder:

    flutter pub get
    flutter analyze --no-pub
    flutter test --no-pub --concurrency=1
    python3 -m unittest discover -s backend/tests -v
    flutter build linux --release --no-pub
    python3 scripts/source_comments.py --normalize
    bash scripts/package-linux.sh

The installer bundles the persistent amogos-system DEB from the repository pool. Its packaging script also accepts AMOGOS_SYSTEM_DEB for a freshly rebuilt system package. The Python Linux helpers require python3-apt; package control files list the complete runtime dependencies.

Test installation and privileged package operations only in a disposable live/target environment. The Flutter preview does not perform system installations.
