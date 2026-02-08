import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/shared_item.dart';

class SharedAudioPlayerPage extends StatefulWidget {
  final SharedItem item;

  const SharedAudioPlayerPage({super.key, required this.item});

  static const kPrimary = Color(0xFF1B3A52);

  @override
  State<SharedAudioPlayerPage> createState() => _SharedAudioPlayerPageState();
}

class _SharedAudioPlayerPageState extends State<SharedAudioPlayerPage> {
  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.item.url != null) {
        await _player.setUrl(widget.item.url!);
      } else {
        throw Exception("Audio URL is null");
      }

      _player.durationStream.listen((d) {
        if (d != null && mounted) {
          setState(() => _duration = d);
        }
      });

      _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() => _position = pos);
        }
      });

      setState(() => _isLoading = false);
      _player.play();
    } catch (e) {
      debugPrint('Error loading audio: $e');
      if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading audio: $e')),
          );
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$m:$s';
  }

  Future<void> _seekRelative(int seconds) async {
    if (_duration == Duration.zero) return;
    final current = _position.inSeconds;
    final target = current + seconds;
    final clamped = target.clamp(0, _duration.inSeconds);
    await _player.seek(Duration(seconds: clamped.toInt()));
  }

  @override
  Widget build(BuildContext context) {
    final maxSeconds =
        _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final sliderValue = _position.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: SharedAudioPlayerPage.kPrimary,
        title: Text(widget.item.title),
         titleTextStyle: const TextStyle(
          fontSize: 28,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 42),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(
                        color: SharedAudioPlayerPage.kPrimary.withOpacity(0.85),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                         const Icon(
                            Icons.audiotrack,
                            size: 80,
                            color: SharedAudioPlayerPage.kPrimary,
                          ),
                          const SizedBox(height: 32),
                          if (_isLoading)
                            const CircularProgressIndicator()
                          else
                            Column(
                              children: [
                                Slider(
                                  min: 0,
                                  max: maxSeconds,
                                  value: sliderValue,
                                  onChanged: (value) {
                                    _player.seek(Duration(seconds: value.toInt()));
                                  },
                                  activeColor: SharedAudioPlayerPage.kPrimary,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatTime(_position)),
                                    Text(_formatTime(_duration)),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 26),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10),
                                iconSize: 44,
                                color: SharedAudioPlayerPage.kPrimary,
                                onPressed: () => _seekRelative(-10),
                              ),
                              const SizedBox(width: 16),
                              StreamBuilder<PlayerState>(
                                stream: _player.playerStateStream,
                                builder: (context, snapshot) {
                                  final playing =
                                      snapshot.data?.playing ?? false;
                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      shape: const CircleBorder(),
                                      backgroundColor:
                                          SharedAudioPlayerPage.kPrimary,
                                      padding: const EdgeInsets.all(22),
                                    ),
                                    onPressed: _isLoading
                                        ? null
                                        : () => playing
                                            ? _player.pause()
                                            : _player.play(),
                                    child: Icon(
                                      playing ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 60,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.forward_10),
                                iconSize: 44,
                                color: SharedAudioPlayerPage.kPrimary,
                                onPressed: () => _seekRelative(10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
