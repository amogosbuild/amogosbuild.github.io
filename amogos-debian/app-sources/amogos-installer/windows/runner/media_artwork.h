// Native AmogOS installer runner and playback integration.
#pragma once
#include <string>
#include <winrt/Windows.Storage.Streams.h>

winrt::Windows::Storage::Streams::RandomAccessStreamReference
    MediaArtwork(const std::string& path);
