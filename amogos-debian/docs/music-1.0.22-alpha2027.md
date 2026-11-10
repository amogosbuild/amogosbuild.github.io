# AmogOS Music 1.0.22-alpha, build 2027

Linux binary release for AmogOS 2 Pro and Debian 13 amd64, built with
Flutter 3.0.5 / Dart 2.17.6 from Music 1.0.22-alpha+2027.
APT package version: **1.0.22~alpha2027**. Application ID: amogos.music.
Terminal command: amogos-music.

This publishes the latest Music binaries, including the scrolling-text edge
fade and Linux MPRIS media controls. Other application and system package
versions remain unchanged. No ISO is rebuilt by this release.

## Install or upgrade

    sudo apt update
    sudo apt install amogos-music

The previous Music package remains available under its immutable filename.
APT selects the higher version automatically. The AppImage is a separate
x86_64 build with bundled GTK/GStreamer libraries and codecs; it targets
glibc 2.41 or newer.

## Verification

- Static analysis reported no issues; dependency lock versions were preserved.
- The broad test run passed 435 checks. Eleven affected test files were then
  rerun with Linux audio fixtures and their required test font: all 51 targeted
  checks passed. Counts overlap. The Windows-specific just_audio fixture is
  excluded on Linux, which uses the separately checked GStreamer backend.
- Both packages contain the current release AOT binary and the matching SDK
  engine. Both launch and render as a regular user with the correct GTK
  application ID and responding MPRIS controls.
- Native local playback, duration, pause, seek and playback through the Dart
  range relay passed using a silent test output. AppImage codec round trips
  passed for WAV, MP3, Opus, Vorbis, FLAC and AAC.
- A real isolated APT client detected the upgrade from 1.0.20~alpha2022 and
  authenticated the new download. Repository signatures, indexes, catalog and
  package checksums passed validation.
- Physical sound devices and every live online provider were not certified by
  these build checks.

## Binaries

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| amogos-music_1.0.22~alpha2027_amd64.deb | 8975844 | 41d1d7a6502839b7ecfa72602f63b2b48890da9e94836eb6b73327418032b77c |
| AmogOS-Music-1.0.22-alpha2027-x86_64.AppImage | 147159544 | 39d82511147b4ce59ab2516ba2d90461f955f762e0f6d5ae2ec87b1b3305834c |
