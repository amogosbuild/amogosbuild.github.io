// Material 3 music dialog exposes playback, queue management, search, and the installer playlist.
import 'package:flutter/material.dart';

import 'music_controller.dart';
import 'source/models/track.dart';
import '../../app/theme.dart';

Future<void> showMusicDialog(BuildContext context, MusicController music) =>
    showDialog<void>(
      context: context,
      builder: (context) => MusicDialog(music: music),
    );

class MusicDialog extends StatefulWidget {
  const MusicDialog({super.key, required this.music});
  final MusicController music;
  @override
  State<MusicDialog> createState() => _MusicDialogState();
}

class _MusicDialogState extends State<MusicDialog> {
  final search = TextEditingController(), playlist = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.music.queue.isEmpty && !widget.music.loading) {
      widget.music.loadInstallerPlaylist();
    }
  }

  @override
  void dispose() {
    search.dispose();
    playlist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.music,
    builder: (context, _) {
      final m = widget.music;
      final small =
          MediaQuery.sizeOf(context).width < 800 ||
          MediaQuery.sizeOf(context).height < 620;
      final library = DefaultTabController(
        length: small ? 3 : 2,
        child: Column(
          children: [
            TabBar(
              tabs: [
                if (small) const Tab(text: 'Player'),
                const Tab(text: 'Up next'),
                const Tab(text: 'Find music'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  if (small) _NowPlaying(music: m),
                  ListView(
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text('${m.queue.length} songs in your queue'),
                          IconButton(
                            tooltip: 'Reload installer playlist',
                            onPressed: m.loading
                                ? null
                                : m.loadInstallerPlaylist,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      if (m.loading && m.queue.isEmpty)
                        const LinearProgressIndicator(),
                      if (!m.loading && m.queue.isEmpty)
                        const Text(
                          'Connect to the internet to load your playlist.',
                        ),
                      for (var i = 0; i < m.queue.length; i++)
                        _TrackTile(
                          track: m.queue[i],
                          active: m.index == i,
                          onTap: () => m.playAt(i),
                          trailing: IconButton(
                            tooltip: 'Remove from queue',
                            onPressed: m.index == i
                                ? null
                                : () => m.removeAt(i),
                            icon: const Icon(Icons.close_rounded, size: 17),
                          ),
                        ),
                    ],
                  ),
                  ListView(
                    children: [
                      TextField(
                        controller: search,
                        onSubmitted: m.search,
                        decoration: InputDecoration(
                          hintText: 'Search songs or artists',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Search',
                            onPressed: () => m.search(search.text),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: playlist,
                        onSubmitted: m.loadPlaylist,
                        decoration: InputDecoration(
                          hintText: 'Or paste a playlist link',
                          prefixIcon: const Icon(Icons.playlist_add_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Load playlist',
                            onPressed: () => m.loadPlaylist(playlist.text),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (m.searching) const LinearProgressIndicator(),
                      for (final track in m.results)
                        _TrackTile(
                          track: track,
                          onTap: () {
                            m.add(track);
                            m.playAt(
                              m.queue.indexWhere((v) => v.id == track.id),
                            );
                          },
                          trailing: IconButton(
                            tooltip: 'Add to queue',
                            onPressed: () => m.add(track),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      return Dialog(
        insetPadding: EdgeInsets.all(small ? 12 : 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940, maxHeight: 680),
          child: Padding(
            padding: EdgeInsets.all(small ? 12 : 26),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        small
                            ? 'Your soundtrack'
                            : 'Your installation soundtrack',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Tooltip(
                      message: 'Enable background music',
                      child: Switch(value: m.enabled, onChanged: m.setEnabled),
                    ),
                    IconButton(
                      tooltip: 'Close music player',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!m.enabled)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Background music is off. Your installation keeps going.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: small
                      ? library
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 300, child: _NowPlaying(music: m)),
                            const SizedBox(width: 24),
                            const VerticalDivider(),
                            const SizedBox(width: 20),
                            Expanded(child: library),
                          ],
                        ),
                ),
                if (m.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      m.error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.music});
  final MusicController music;
  String time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final m = music, c = Theme.of(context).colorScheme;
    final duration = m.duration.inMilliseconds.toDouble();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height < 620 ? 100 : 250,
              width: double.infinity,
              child: m.current?.artwork.isNotEmpty == true
                  ? Image.network(
                      m.current!.artwork,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => _art(),
                    )
                  : _art(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            m.current?.title ?? 'Set the mood.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            m.current?.artist ?? 'Your favorite songs. Your fresh start.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Slider(
            value: duration <= 0
                ? 0
                : m.position.inMilliseconds.clamp(0, duration).toDouble(),
            max: duration > 0 ? duration : 1,
            onChanged: m.current == null
                ? null
                : (v) => m.seek(Duration(milliseconds: v.round())),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time(m.position),
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 11),
              ),
              Text(
                time(m.duration),
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Shuffle',
                color: m.shuffle ? c.primary : c.onSurfaceVariant,
                onPressed: m.toggleShuffle,
                icon: const Icon(Icons.shuffle_rounded, size: 20),
              ),
              IconButton(
                tooltip: 'Previous',
                onPressed: m.previous,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: m.loading ? null : m.toggle,
                child: m.loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        m.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: m.next,
                icon: const Icon(Icons.skip_next_rounded),
              ),
              IconButton(
                tooltip: [
                  'Repeat off',
                  'Repeat playlist',
                  'Repeat track',
                ][m.repeat],
                color: m.repeat > 0 ? c.primary : c.onSurfaceVariant,
                onPressed: m.cycleRepeat,
                icon: Icon(
                  m.repeat == 2
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  size: 20,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Mute',
                onPressed: () => m.setVolume(m.volume > 0 ? 0 : .45),
                icon: Icon(
                  m.volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size: 19,
                ),
              ),
              Expanded(
                child: Slider(value: m.volume, onChanged: m.setVolume),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _art() => Container(
    decoration: const BoxDecoration(gradient: installGradient),
    child: Center(child: Image.asset('assets/images/amogus.png', height: 160)),
  );
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.onTap,
    required this.trailing,
    this.active = false,
  });
  final Track track;
  final VoidCallback onTap;
  final Widget trailing;
  final bool active;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    selected: active,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 38,
        height: 38,
        child: track.artwork.isEmpty
            ? const Icon(Icons.music_note_rounded)
            : Image.network(
                track.artwork,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => const Icon(Icons.music_note_rounded),
              ),
      ),
    ),
    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      track.artist,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11),
    ),
    trailing: trailing,
    onTap: onTap,
  );
}
