import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/shared_item.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class SharedAudioPlayerPage extends StatefulWidget {
  final SharedItem item;
  const SharedAudioPlayerPage({super.key, required this.item});

  @override
  State<SharedAudioPlayerPage> createState() => _SharedAudioPlayerPageState();
}

class _SharedAudioPlayerPageState extends State<SharedAudioPlayerPage>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _kNavy = Color(0xFF102E50);
  static const _kBlue = Color(0xFF0077B6);
  static const _kBg = Color(0xFFF7F8FA);

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
      if (widget.item.url != null) {
        await _player.setUrl(widget.item.url!);
      } else {
        throw Exception('Audio URL is null');
      }

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
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorLoadingAudio(e.toString()),
            ),
          ),
        );
      }
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
    final maxSec = _duration.inSeconds > 0
        ? _duration.inSeconds.toDouble()
        : 1.0;
    final curSec = _position.inSeconds.toDouble().clamp(0.0, maxSec);
    final title = widget.item.title.isNotEmpty ? widget.item.title : 'Audio';

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: Color(0xFF1A2340),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'AUDIO'.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kBlue,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            const Spacer(),

            // ── Artwork placeholder ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 52),
              child: ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _kBlue.withOpacity(0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.audiotrack_rounded,
                      size: 90,
                      color: _kBlue,
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
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2340),
                  height: 1.3,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Sender label
            if (widget.item.senderId.isNotEmpty)
              Text(
                'From family',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
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
                      activeTrackColor: _kBlue,
                      inactiveTrackColor: _kBlue.withOpacity(0.15),
                      thumbColor: _kBlue,
                      overlayColor: _kBlue.withOpacity(0.12),
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
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CtrlBtn(
                    icon: Icons.replay_10,
                    size: 30,
                    onTap: () => _seekRelative(-10),
                  ),

                  // Play / Pause
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
                            color: _kBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _kBlue.withOpacity(0.35),
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

                  _CtrlBtn(
                    icon: Icons.forward_10,
                    size: 30,
                    onTap: () => _seekRelative(10),
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

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _CtrlBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Icon(icon, size: size, color: const Color(0xFF1A2340)),
      ),
    );
  }
}
