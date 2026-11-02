// Native AmogOS installer runner and playback integration.
#include "media_artwork.h"
#include <shlwapi.h>
#include <shcore.h>

winrt::Windows::Storage::Streams::RandomAccessStreamReference
    MediaArtwork(const std::string& path) {
  using namespace winrt::Windows::Storage::Streams;
  winrt::com_ptr<IStream> source;
  winrt::check_hresult(SHCreateStreamOnFileEx(winrt::to_hstring(path).c_str(),
      STGM_READ | STGM_SHARE_DENY_NONE, FILE_ATTRIBUTE_NORMAL, FALSE,
      nullptr, source.put()));
  IRandomAccessStream stream{nullptr};
  winrt::check_hresult(CreateRandomAccessStreamOverStream(source.get(),
      BSOS_DEFAULT, winrt::guid_of<IRandomAccessStream>(), winrt::put_abi(stream)));
  return RandomAccessStreamReference::CreateFromStream(stream);
}
