import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/audio_item.dart';

class AudioPlayerPage extends StatefulWidget {
  final AudioItem item;

  const AudioPlayerPage({super.key, required this.item});

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
      // 1) حمل الملف من assets/audio/<fileName>
      await _player.setAsset('assets/audio/${widget.item.fileName}');

      // 2) اسمع لتغيّر الـ duration
      _player.durationStream.listen((d) {
        if (d != null && mounted) {
          setState(() {
            _duration = d;
          });
        }
      });

      // 3) اسمع لتغيّر الـ position
      _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      });

      // 4) اعتبر أن التحميل خلص → شيل علامة اللودينق
      setState(() {
        _isLoading = false;
      });

      // 5) ابدأ التشغيل تلقائياً
      _player.play();
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
    final sliderValue = currentSeconds.clamp(0.0, maxSeconds);

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: AudioPlayerPage.kPrimary,

        // ✅ العنوان في الـ AppBar (يقلّ الخط لو العنوان طويل)
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(widget.item.title, textAlign: TextAlign.center),
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
          // 🔹 قللنا البادينق الأفقي عشان نعطي مساحة أكبر للأزرار
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Expanded(
                child: Center(
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    shadowColor: AudioPlayerPage.kPrimary.withOpacity(0.15),
                    // 🔹 قللنا الـ margin شوي
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(
                        color: AudioPlayerPage.kPrimary.withOpacity(0.85),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      // 🔹 قللنا البادينق الأفقي داخل الكرت
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 26,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ===== العنوان + صورة =====
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundImage:
                                    AssetImage(widget.item.imageAsset),
                              ),
                              const SizedBox(width: 16),

                              Expanded(
                                child: Text(
                                  widget.item.title,
                                  softWrap: true,
                                  maxLines: 3,
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

                          const SizedBox(height: 32),

                          // ===== الـ Slider =====
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
                                    thumbShape:
                                        const RoundSliderThumbShape(
                                      enabledThumbRadius: 10,
                                    ),
                                    overlayShape:
                                        const RoundSliderOverlayShape(
                                      overlayRadius: 18,
                                    ),
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

                          const SizedBox(height: 26),

                          // ===== أزرار التحكم (نفس المقاسات السابقة) =====
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ⏪ رجوع 10 ثواني
                              IconButton(
                                icon: const Icon(Icons.replay_10),
                                iconSize: 44, // 👈 نفس اللي كان
                                color: AudioPlayerPage.kPrimary,
                                onPressed: () => _seekRelative(-10),
                                splashRadius: 30,
                              ),
                              const SizedBox(width: 16),

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
                                      padding: const EdgeInsets.all(
                                          22), // 👈 نفس اللي كان
                                      elevation: 4,
                                    ),
                                    onPressed: onPressed,
                                    child: Icon(
                                      icon,
                                      color: Colors.white,
                                      size: 60, // 👈 نفس اللي كان
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),

                              // ⏩ تقدّم 10 ثواني
                              IconButton(
                                icon: const Icon(Icons.forward_10),
                                iconSize: 44, // 👈 نفس اللي كان
                                color: AudioPlayerPage.kPrimary,
                                onPressed: () => _seekRelative(10),
                                splashRadius: 30,
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          const Text(
                            "Tap play to start listening",
                            textAlign: TextAlign.center,
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
