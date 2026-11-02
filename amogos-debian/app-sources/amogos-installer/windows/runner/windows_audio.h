// Native AmogOS installer runner and playback integration.
#pragma once
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Core.h>
#include <winrt/Windows.Media.Playback.h>
#include <winrt/Windows.Storage.Streams.h>
#include <atomic>
#include <memory>
#include <mutex>

class WindowsAudio {
 public:
  static constexpr UINT kControlMessage = WM_APP + 83;
  WindowsAudio(flutter::BinaryMessenger* messenger, HWND window);
  ~WindowsAudio();
  bool HandleMessage(UINT message, WPARAM command);

 private:
  struct State {
    std::atomic<bool> ended{false};
    std::mutex mutex;
    std::string error;
  };
  struct Controls {
    HWND window;
    std::atomic<bool> active{true};
    explicit Controls(HWND handle) : window(handle) {}
  };
  void Initialize();
  void Load(const std::string& uri);
  void Call(const flutter::MethodCall<flutter::EncodableValue>& call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  winrt::Windows::Media::Playback::MediaPlayer player_{nullptr};
  winrt::Windows::Media::SystemMediaTransportControls transport_{nullptr};
  std::shared_ptr<State> state_;
  std::shared_ptr<Controls> controls_;
  winrt::event_token ended_{}, failed_{}, button_{};
};
