// Native AmogOS installer runner and playback integration.
#include "windows_audio.h"
#include <chrono>
#include <exception>
#include <systemmediatransportcontrolsinterop.h>
#include "media_artwork.h"

using flutter::EncodableMap;
using flutter::EncodableValue;
using namespace winrt::Windows::Media;
using namespace winrt::Windows::Media::Playback;
using winrt::Windows::Foundation::Uri;
using winrt::Windows::Foundation::TimeSpan;

namespace {
const EncodableValue& Value(const EncodableMap& values, const char* key) {
  static const EncodableValue empty;
  const auto entry = values.find(EncodableValue(key));
  return entry == values.end() ? empty : entry->second;
}
std::string String(const EncodableMap& values, const char* key) {
  const auto value = std::get_if<std::string>(&Value(values, key));
  return value ? *value : "";
}
int64_t Number(const EncodableValue& value) {
  if (const auto number = std::get_if<int32_t>(&value)) return *number;
  if (const auto number = std::get_if<int64_t>(&value)) return *number;
  return 0;
}
}

WindowsAudio::WindowsAudio(flutter::BinaryMessenger* messenger, HWND window)
    : controls_(std::make_shared<Controls>(window)) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "amogos.windows_audio", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    Call(call, std::move(result));
  });
}

WindowsAudio::~WindowsAudio() {
  controls_->active = false;
  channel_->SetMethodCallHandler(nullptr);
  if (player_) {
    try {
      transport_.ButtonPressed(button_);
      player_.MediaEnded(ended_);
      player_.MediaFailed(failed_);
      transport_.IsEnabled(false);
      player_.Close();
    } catch (...) {}
  }
}

void WindowsAudio::Initialize() {
  if (player_) return;
  auto player = MediaPlayer();
  player.AutoPlay(false);
  player.CommandManager().IsEnabled(false);
  player.SystemMediaTransportControls().IsEnabled(false);
  SystemMediaTransportControls transport{nullptr};
  const auto interop = winrt::get_activation_factory<SystemMediaTransportControls,
      ISystemMediaTransportControlsInterop>();
  winrt::check_hresult(interop->GetForWindow(controls_->window,
      winrt::guid_of<SystemMediaTransportControls>(), winrt::put_abi(transport)));
  player_ = std::move(player);
  transport_ = std::move(transport);
  auto controls = transport_;
  controls.IsEnabled(true);
  controls.IsPlayEnabled(true);
  controls.IsPauseEnabled(true);
  controls.IsStopEnabled(true);
  controls.IsNextEnabled(true);
  controls.IsPreviousEnabled(true);
  controls.DisplayUpdater().Type(MediaPlaybackType::Music);
  const std::weak_ptr<Controls> weak = controls_;
  button_ = controls.ButtonPressed([weak](auto, auto args) {
    if (const auto state = weak.lock(); state && state->active) {
      PostMessage(state->window, kControlMessage,
                  static_cast<WPARAM>(args.Button()), 0);
    }
  });
}

void WindowsAudio::Load(const std::string& uri) {
  Initialize();
  player_.Pause();
  player_.MediaEnded(ended_);
  player_.MediaFailed(failed_);
  state_ = std::make_shared<State>();
  const std::weak_ptr<State> weak = state_;
  ended_ = player_.MediaEnded([weak](auto, auto) {
    if (const auto state = weak.lock()) state->ended = true;
  });
  failed_ = player_.MediaFailed([weak](auto, auto args) {
    if (const auto state = weak.lock()) {
      std::lock_guard<std::mutex> lock(state->mutex);
      state->error = winrt::to_string(args.ErrorMessage());
      if (state->error.empty()) state->error = "Windows cannot decode this audio format.";
    }
  });
  player_.Source(winrt::Windows::Media::Core::MediaSource::CreateFromUri(
      Uri(winrt::to_hstring(uri))));
}

bool WindowsAudio::HandleMessage(UINT message, WPARAM command) {
  if (message != kControlMessage) return false;
  std::string action;
  switch (static_cast<SystemMediaTransportControlsButton>(command)) {
    case SystemMediaTransportControlsButton::Play: action = "play"; break;
    case SystemMediaTransportControlsButton::Pause: action = "pause"; break;
    case SystemMediaTransportControlsButton::Stop: action = "stop"; break;
    case SystemMediaTransportControlsButton::Next: action = "next"; break;
    case SystemMediaTransportControlsButton::Previous: action = "previous"; break;
    default: return true;
  }
  channel_->InvokeMethod("control", std::make_unique<EncodableValue>(action));
  return true;
}

void WindowsAudio::Call(const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  try {
    Initialize();
    const EncodableMap empty;
    const auto map = call.arguments() ? std::get_if<EncodableMap>(call.arguments()) : nullptr;
    const auto& args = map ? *map : empty;
    const auto& method = call.method_name();
    if (method == "load") {
      Load(String(args, "uri"));
    } else if (method == "play") {
      player_.Play();
      transport_.PlaybackStatus(MediaPlaybackStatus::Playing);
    } else if (method == "pause") {
      player_.Pause();
      transport_.PlaybackStatus(MediaPlaybackStatus::Paused);
    } else if (method == "stop") {
      player_.Pause();
      player_.Source(nullptr);
      state_.reset();
      transport_.PlaybackStatus(MediaPlaybackStatus::Stopped);
    } else if (method == "seek") {
      if (player_.PlaybackSession().CanSeek()) {
        player_.PlaybackSession().Position(TimeSpan(std::chrono::milliseconds(
            Number(call.arguments() ? *call.arguments() : EncodableValue()))));
      }
      if (state_) state_->ended = false;
    } else if (method == "volume") {
      if (const auto value = call.arguments() ? std::get_if<double>(call.arguments()) : nullptr) {
        player_.Volume(*value);
      }
    } else if (method == "metadata") {
      auto updater = transport_.DisplayUpdater();
      updater.ClearAll();
      updater.Type(MediaPlaybackType::Music);
      auto music = updater.MusicProperties();
      music.Title(winrt::to_hstring(String(args, "title")));
      music.Artist(winrt::to_hstring(String(args, "artist")));
      music.AlbumTitle(winrt::to_hstring(String(args, "album")));
      const auto artwork = String(args, "artworkPath");
      if (!artwork.empty()) {
        try {
          updater.Thumbnail(MediaArtwork(artwork));
        } catch (const winrt::hresult_error&) {}
      }
      updater.Update();
    } else if (method == "state") {
      auto session = player_.PlaybackSession();
      const auto position = session.Position().count() / 10000;
      const auto duration = session.NaturalDuration().count() / 10000;
      const auto state = session.PlaybackState();
      const auto ended = state_ && state_->ended.exchange(false);
      transport_.PlaybackStatus(
          state == MediaPlaybackState::Playing ? MediaPlaybackStatus::Playing :
          state == MediaPlaybackState::None || ended ? MediaPlaybackStatus::Stopped :
          MediaPlaybackStatus::Paused);
      std::string processing = state == MediaPlaybackState::Opening ? "loading" :
          state == MediaPlaybackState::Buffering ? "buffering" :
          state == MediaPlaybackState::None ? "idle" : "ready";
      EncodableMap values{
          {EncodableValue("position"), EncodableValue(static_cast<int64_t>(position))},
          {EncodableValue("duration"), EncodableValue(static_cast<int64_t>(duration))},
          {EncodableValue("playing"), EncodableValue(state == MediaPlaybackState::Playing)},
          {EncodableValue("processing"), EncodableValue(ended ? "completed" : processing)},
          {EncodableValue("completed"), EncodableValue(ended)}};
      values[EncodableValue("title")] = EncodableValue(winrt::to_string(
          transport_.DisplayUpdater().MusicProperties().Title()));
      values[EncodableValue("artist")] = EncodableValue(winrt::to_string(
          transport_.DisplayUpdater().MusicProperties().Artist()));
      values[EncodableValue("hasArtwork")] = EncodableValue(
          transport_.DisplayUpdater().Thumbnail() != nullptr);
      if (state_) {
        std::lock_guard<std::mutex> lock(state_->mutex);
        if (!state_->error.empty()) {
          values[EncodableValue("error")] = EncodableValue(state_->error);
          state_->error.clear();
        }
      }
      result->Success(EncodableValue(values));
      return;
    } else if (method != "init") {
      result->NotImplemented();
      return;
    }
    result->Success();
  } catch (const winrt::hresult_error& error) {
    result->Error("windows_audio", winrt::to_string(error.message()));
  } catch (const std::exception& error) {
    result->Error("windows_audio", error.what());
  }
}
