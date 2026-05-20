import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/audio_item.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class AudioPlayerPage extends StatefulWidget {
  final AudioItem item;
  const AudioPlayerPage({super.key, required this.item});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;

  // Subtle pulse animation on the artwork while playing
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Palette ───────────────────────────────────────────────────────────────
  static const _kNavy = Color(0xFF102E50);
  static const _kTeal = Color(0xFF4E949C);
  static const _kGreen = Color(0xFF3A8C78);
  static const _kGold = Color(0xFFF5C35D);
  static const _kBg = Color(0xFFF7F8FA);

  Color get _accent {
    switch (widget.item.category) {
      case 'Quran':
        return _kTeal;
      case 'Story':
        return _kNavy;
      case 'Health':
        return _kGreen;
      default:
        return _kNavy;
    }
  }

  String _getTitle() {
    final lang = Localizations.localeOf(context).languageCode;
    if (widget.item.category == 'Quran' && lang == 'ar') {
      return widget.item.titleAr?.isNotEmpty == true
          ? widget.item.titleAr!
          : widget.item.title;
    }
    return widget.item.title;
  }

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setAsset('assets/audio/${widget.item.fileName}');

      _player.durationStream.listen((d) {
        if (d != null && mounted) setState(() => _duration = d);
      });

      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });

      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        if (state.playing) {
          _pulseCtrl.repeat(reverse: true);
        } else {
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      });

      setState(() => _isLoading = false);
      _player.play();
    } catch (e) {
      debugPrint('Error loading audio: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  Future<void> _seekRelative(int seconds) async {
    if (_duration == Duration.zero) return;
    final target = (_position.inSeconds + seconds).clamp(
      0,
      _duration.inSeconds,
    );
    await _player.seek(Duration(seconds: target));
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final maxSec = _duration.inSeconds > 0
        ? _duration.inSeconds.toDouble()
        : 1.0;
    final curSec = _position.inSeconds.toDouble().clamp(0.0, maxSec);
    final title = _getTitle();
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 50, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Color(0xFF1A2340),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Color.fromARGB(
                        255,
                        230,
                        232,
                        234,
                      ), // light circle
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.item.category.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  // Placeholder to balance the row
                  const SizedBox(width: 44),
                ],
              ),
            ),

            const Spacer(),

            // ── Artwork ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.22),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      widget.item.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 280,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: accent,
                          size: 80,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // ── Title ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2340),
                  height: 1.3,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Progress bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      trackHeight: 4,
                      activeTrackColor: accent,
                      inactiveTrackColor: accent.withOpacity(0.15),
                      thumbColor: accent,
                      overlayColor: accent.withOpacity(0.12),
                    ),
                    child: Slider(
                      min: 0,
                      max: maxSec,
                      value: curSec,
                      onChanged: (v) =>
                          _player.seek(Duration(seconds: v.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(_position),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        Text(
                          _formatTime(_duration),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Controls ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // −30 s
                  _ControlButton(
                    icon: Icons.replay_30,
                    size: 30,
                    color: const Color(0xFF1A2340),
                    onTap: () => _seekRelative(-30),
                  ),

                  // −10 s
                  _ControlButton(
                    icon: Icons.replay_10,
                    size: 34,
                    color: const Color(0xFF1A2340),
                    onTap: () => _seekRelative(-10),
                  ),

                  // Play / Pause — large pill button
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snap) {
                      final playing = snap.data?.playing ?? false;
                      return GestureDetector(
                        onTap: () => playing ? _player.pause() : _player.play(),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                        ),
                      );
                    },
                  ),

                  // +10 s
                  _ControlButton(
                    icon: Icons.forward_10,
                    size: 34,
                    color: const Color(0xFF1A2340),
                    onTap: () => _seekRelative(10),
                  ),

                  // +30 s
                  _ControlButton(
                    icon: Icons.forward_30,
                    size: 30,
                    color: const Color(0xFF1A2340),
                    onTap: () => _seekRelative(30),
                  ),
                ],
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ── Small control button ──────────────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
