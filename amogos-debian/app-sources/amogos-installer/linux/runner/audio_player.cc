// Native AmogOS installer runner and playback integration.
#include "audio_player.h"
#include <gst/gst.h>
#include <cstring>

struct AudioPlayer {
  GstElement* pipeline;
  bool completed;
  gchar* error;
};

static void destroy_player(gpointer data) {
  AudioPlayer* player = static_cast<AudioPlayer*>(data);
  gst_element_set_state(player->pipeline, GST_STATE_NULL);
  gst_object_unref(player->pipeline);
  g_free(player->error);
  delete player;
}

static void handle_audio(FlMethodChannel* channel, FlMethodCall* call, gpointer data) {
  AudioPlayer* player = static_cast<AudioPlayer*>(data);
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  g_autoptr(FlValue) result = fl_value_new_null();
  if (std::strcmp(method, "load") == 0) {
    FlValue* uri = fl_value_lookup_string(args, "uri");
    gst_element_set_state(player->pipeline, GST_STATE_NULL);
    g_object_set(player->pipeline, "uri", fl_value_get_string(uri), nullptr);
    player->completed = false;
    g_clear_pointer(&player->error, g_free);
    gst_element_set_state(player->pipeline, GST_STATE_PAUSED);
  } else if (std::strcmp(method, "play") == 0) {
    gst_element_set_state(player->pipeline, GST_STATE_PLAYING);
  } else if (std::strcmp(method, "pause") == 0) {
    gst_element_set_state(player->pipeline, GST_STATE_PAUSED);
  } else if (std::strcmp(method, "seek") == 0) {
    gst_element_seek_simple(player->pipeline, GST_FORMAT_TIME,
      static_cast<GstSeekFlags>(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT), fl_value_get_int(args) * GST_MSECOND);
  } else if (std::strcmp(method, "volume") == 0) {
    g_object_set(player->pipeline, "volume", fl_value_get_float(args), nullptr);
  } else if (std::strcmp(method, "dispose") == 0) {
    gst_element_set_state(player->pipeline, GST_STATE_NULL);
  } else if (std::strcmp(method, "state") == 0) {
    GstBus* bus = gst_element_get_bus(player->pipeline);
    GstMessage* message;
    while ((message = gst_bus_pop_filtered(bus, static_cast<GstMessageType>(GST_MESSAGE_ERROR | GST_MESSAGE_EOS))) != nullptr) {
      if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_EOS) player->completed = true;
      if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_ERROR) {
        GError* error = nullptr;
        gst_message_parse_error(message, &error, nullptr);
        g_clear_pointer(&player->error, g_free);
        player->error = g_strdup(error->message);
        g_error_free(error);
      }
      gst_message_unref(message);
    }
    gst_object_unref(bus);
    gint64 position = 0, duration = 0;
    gst_element_query_position(player->pipeline, GST_FORMAT_TIME, &position);
    gst_element_query_duration(player->pipeline, GST_FORMAT_TIME, &duration);
    g_clear_pointer(&result, fl_value_unref);
    result = fl_value_new_map();
    fl_value_set_string_take(result, "position", fl_value_new_int(position / GST_MSECOND));
    fl_value_set_string_take(result, "duration", fl_value_new_int(duration / GST_MSECOND));
    fl_value_set_string_take(result, "completed", fl_value_new_bool(player->completed));
    if (player->error) fl_value_set_string_take(result, "error", fl_value_new_string(player->error));
    player->completed = false;
    g_clear_pointer(&player->error, g_free);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  fl_method_call_respond_success(call, result, nullptr);
}

void register_audio_player(FlBinaryMessenger* messenger) {
  gst_init(nullptr, nullptr);
  GstElement* pipeline = gst_element_factory_make("playbin", "amogos-player");
  if (!pipeline) return;
  AudioPlayer* player = new AudioPlayer{pipeline, false, nullptr};
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(messenger, "amogos.audio", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, handle_audio, player, destroy_player);
}
