# AmogOS Music 1.0.23-alpha, build 2032

Linux x86_64 release for AmogOS 2 Pro and Debian 13, built with Flutter
3.0.5 and Dart 2.17.6. APT installs amogos-music version
**1.0.23~alpha2032**. Launch it with amogos-music.

## Install or upgrade

    sudo apt update
    sudo apt install amogos-music

## Downloads

- [AppImage, DEB and SHA-256 files on Filekiwi](https://file.kiwi/b3c7068f#55E_nFOQ2VFF3QWokZDSXA) (temporary)
- [DEB in the signed APT archive](../pool/main/a/amogos-music/amogos-music_1.0.23~alpha2032_amd64.deb)

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| amogos-music_1.0.23~alpha2032_amd64.deb | 9055704 | ce6622c85ca3917fba422f1990707dd48a816be835f30b1de0bf3e7ec284c545 |
| AmogOS-Music-1.0.23-alpha2032-x86_64.AppImage | 147261944 | 760f679e689d8855fd4da4109e40d4c9dd06fa0765df8b50f4bb1ee8192bd29f |

## Verification

Both packages contain the same release application and Flutter engine. Both
launched as a regular user and responded to MPRIS commands. The DEB upgraded
from 1.0.22~alpha2027. The AppImage passed codec checks for WAV, MP3, Opus,
Vorbis, FLAC and AAC.

Flutter analysis passed and 111 targeted tests passed.
