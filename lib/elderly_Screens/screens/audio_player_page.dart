import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/audio_item.dart';

class AudioPlayerPage extends StatefulWidget {
  final AudioItem item;

  const AudioPlayerPage({
    super.key,
    required this.item,
  });

  static const kPrimary = Color(0xFF1B3A52);

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
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
      // نحمل الملف من assets/audio/<fileName>
      await _player.setAsset('assets/audio/${widget.item.fileName}');

      // نسمع لتغيّر الـ duration
      _player.durationStream.listen((d) {
        if (d != null && mounted) {
          setState(() {
            _duration = d;
          });
        }
      });

      // نسمع لتغيّر الـ position
      _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading audio: $e');
      setState(() {
        _isLoading = false;
      });
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

  /// ⏪ / ⏩ قفزة نسبية بعدد ثواني (سالب يرجع، موجب يتقدّم)
  Future<void> _seekRelative(int seconds) async {
    if (_duration == Duration.zero) return;

    final current = _position.inSeconds;
    final target = current + seconds;

    final minSec = 0;
    final maxSec = _duration.inSeconds;

    final clamped = target.clamp(minSec, maxSec); // num
    await _player.seek(Duration(seconds: clamped.toInt()));
  }

  @override
  Widget build(BuildContext context) {
    // أقصى قيمة للـ Slider
    final maxSeconds =
        _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;

    // القيمة الحالية للـ Slider
    final currentSeconds = _position.inSeconds.toDouble();
    final sliderValue =
        currentSeconds.clamp(0.0, maxSeconds); // double بين 0 و max

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: AudioPlayerPage.kPrimary,

        // ✅ تعديل العنوان هنا: FittedBox عشان العنوان الطويل يصغر بدال ما ينقص
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.item.title,
            textAlign: TextAlign.center,
          ),
        ),

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
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Expanded(
                child: Center(
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    shadowColor: AudioPlayerPage.kPrimary.withOpacity(0.15),
                    margin: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(
                        color: AudioPlayerPage.kPrimary.withOpacity(0.85),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // العنوان + صورة
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundImage:
                                    AssetImage(widget.item.imageAsset),
                              ),
                              const SizedBox(width: 20),

                              // ✅ تعديل العنوان داخل الكرت: بدون ellipsis ويلتف على عدة أسطر
                              Expanded(
                                child: Text(
                                  widget.item.title,
                                  softWrap: true,
                                  maxLines: 3, // زيديه لو تبين أكثر
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansArabic',
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AudioPlayerPage.kPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // المؤشر (Slider)
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(),
                            )
                          else
                            Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 10),
                                    overlayShape:
                                        const RoundSliderOverlayShape(
                                            overlayRadius: 18),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: maxSeconds,
                                    value: sliderValue,
                                    onChanged: (value) {
                                      final pos =
                                          Duration(seconds: value.toInt());
                                      _player.seek(pos);
                                    },
                                    activeColor: AudioPlayerPage.kPrimary,
                                    inactiveColor: Colors.grey[300],
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatTime(_position),
                                      style: const TextStyle(
                                        fontFamily: 'NotoSansArabic',
                                        fontSize: 18,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      _formatTime(_duration),
                                      style: const TextStyle(
                                        fontFamily: 'NotoSansArabic',
                                        fontSize: 18,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                          const SizedBox(height: 30),

                          // أزرار التحكم
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ⏪ رجوع 10 ثواني
                              IconButton(
                                icon: const Icon(Icons.replay_10),
                                iconSize: 50,
                                color: AudioPlayerPage.kPrimary,
                                onPressed: () => _seekRelative(-10),
                                splashRadius: 30,
                              ),
                              const SizedBox(width: 20),

                              // Play / Pause
                              StreamBuilder<PlayerState>(
                                stream: _player.playerStateStream,
                                builder: (context, snapshot) {
                                  final state = snapshot.data;
                                  final playing = state?.playing ?? false;

                                  IconData icon;
                                  VoidCallback? onPressed;

                                  if (_isLoading) {
                                    icon = Icons.hourglass_empty;
                                    onPressed = null;
                                  } else if (!playing) {
                                    icon = Icons.play_arrow;
                                    onPressed = () => _player.play();
                                  } else {
                                    icon = Icons.pause;
                                    onPressed = () => _player.pause();
                                  }

                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      shape: const CircleBorder(),
                                      backgroundColor:
                                          AudioPlayerPage.kPrimary,
                                      padding: const EdgeInsets.all(22),
                                      elevation: 4,
                                    ),
                                    onPressed: onPressed,
                                    child: Icon(
                                      icon,
                                      color: Colors.white,
                                      size: 60,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 20),

                              // ⏩ تقدّم 10 ثواني
                              IconButton(
                                icon: const Icon(Icons.forward_10),
                                iconSize: 50,
                                color: AudioPlayerPage.kPrimary,
                                onPressed: () => _seekRelative(10),
                                splashRadius: 30,
                              ),
                            ],
                          ),

                          const SizedBox(height: 25),

                          const Text(
                            "Tap play to start listening",
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontSize: 22,
                              color: Colors.black54,
                            ),
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
