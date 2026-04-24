import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/locale_provider.dart';
import '../../services/voice_assistant_service.dart';
import '../../services/arabic_voice_assistant_service.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';
import '../../services/news_service.dart';

class DailyLibraryPage extends StatefulWidget {
  const DailyLibraryPage({super.key});

  @override
  State<DailyLibraryPage> createState() => _DailyLibraryPageState();
}

class _DailyLibraryPageState extends State<DailyLibraryPage>
    with TickerProviderStateMixin {
  static const Color kPrimary = Color(0xFF1B3A52);
  static const Color kSurface = Color(0xFFF5F5F5);

  final VoiceAssistantService _voice = VoiceAssistantService();
  final ArabicVoiceAssistantService _arabicVoice = ArabicVoiceAssistantService();

  final LocationService locationService = LocationService();
  final WeatherService weatherService = WeatherService();
  final NewsService newsService = NewsService();

  Map<String, dynamic>? weatherData;
  List<Map<String, dynamic>> newsList = [];

  bool isLoadingWeather = true;
  bool isLoadingNews = true;

  late AnimationController _rippleController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  bool _isListening = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _loadWeather();
    _loadNews();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _startAnim() {
    _rippleController.repeat();
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
  }

  void _stopAnim() {
    _rippleController.stop();
    _pulseController.stop();
    _rotateController.stop();
  }

  String getSaudiCity(double lat, double lon, bool isArabic) {
    if (lat >= 24 && lat <= 26 && lon >= 45 && lon <= 47) {
      return isArabic ? 'الرياض' : 'Riyadh';
    }

    if (lat >= 21 && lat <= 22.5 && lon >= 39 && lon <= 40.5) {
      return isArabic ? 'مكة' : 'Makkah';
    }

    if (lat >= 24 && lat <= 25.5 && lon >= 39 && lon <= 40.5) {
      return isArabic ? 'المدينة' : 'Madinah';
    }

    return isArabic ? 'منطقتك' : 'your location';
  }

  Future<void> _loadWeather() async {
    try {
      final localeProvider = Provider.of<LocaleProvider>(
        context,
        listen: false,
      );
      final bool isArabic = localeProvider.isArabic;
      final lang = isArabic ? 'ar' : 'en';

      final position = await locationService.getCurrentLocation();

      final data = await weatherService.getCurrentWeather(
        lat: position.latitude,
        lon: position.longitude,
        lang: lang,
      );

      data['customCityName'] = getSaudiCity(
        position.latitude,
        position.longitude,
        isArabic,
      );

      if (!mounted) return;

      setState(() {
        weatherData = data;
        isLoadingWeather = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingWeather = false;
      });
    }
  }

  Future<void> _loadNews() async {
    try {
      final localeProvider = Provider.of<LocaleProvider>(
        context,
        listen: false,
      );
      final bool isArabic = localeProvider.isArabic;

      final news = await newsService.getTopHeadlines(
        languageCode: isArabic ? 'ar' : 'en',
        country: isArabic ? 'sa' : null,
        maxResults: 3,
        category: 'health',
      );

      if (!mounted) return;

      setState(() {
        newsList = news;
        isLoadingNews = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingNews = false;
      });
    }
  }

  Future<void> _speakWeather() async {
    final localeProvider = Provider.of<LocaleProvider>(
      context,
      listen: false,
    );
    final bool isArabic = localeProvider.isArabic;

    // ✅ Important: initialize TTS before speaking
    if (isArabic) {
      await _arabicVoice.initialize();
    } else {
      await _voice.initialize();
    }

    if (weatherData == null) {
      if (isArabic) {
        await _arabicVoice.speak("عذرًا، لم أتمكن من جلب الطقس الآن.");
      } else {
        await _voice.speak("Sorry, I couldn't get the weather right now.");
      }
      return;
    }

    final city = weatherData!['customCityName'];
    final temp = weatherData!['current']['temp_c'];
    final condition = weatherData!['current']['condition']['text'];

    if (isArabic) {
      await _arabicVoice.speak(
        "الطقس اليوم في $city، $condition، ودرجة الحرارة $temp درجة مئوية",
      );
    } else {
      await _voice.speak(
        "Today's weather in $city is $condition with a temperature of $temp degrees Celsius",
      );
    }
  }

  Future<void> _speakNews() async {
    final localeProvider = Provider.of<LocaleProvider>(
      context,
      listen: false,
    );
    final bool isArabic = localeProvider.isArabic;

    // ✅ Important: initialize TTS before speaking
    if (isArabic) {
      await _arabicVoice.initialize();
    } else {
      await _voice.initialize();
    }

    if (newsList.isEmpty) {
      if (isArabic) {
        await _arabicVoice.speak("عذرًا، لم أجد أخبارًا الآن.");
      } else {
        await _voice.speak("Sorry, I could not find any news right now.");
      }
      return;
    }

    if (isArabic) {
      String speech = "أهم الأخبار اليوم: ";
      for (int i = 0; i < newsList.length; i++) {
        speech += "الخبر ${i + 1}: ${newsList[i]['title']}. ";
      }
      await _arabicVoice.speak(speech);
    } else {
      String speech = "Here are today's top news headlines. ";
      for (int i = 0; i < newsList.length; i++) {
        speech += "News ${i + 1}: ${newsList[i]['title']}. ";
      }
      await _voice.speak(speech);
    }
  }

  Future<void> _startDailyLibraryVoice() async {
    if (_isListening) return;

    final localeProvider = Provider.of<LocaleProvider>(
      context,
      listen: false,
    );
    final bool isArabic = localeProvider.isArabic;

 setState(() {
  _isSpeaking = true;  
  _isListening = false;
});
_startAnim();
HapticFeedback.mediumImpact();

    // ✅ Important: initialize TTS/voice service before speak + listen
    final initialized = isArabic
        ? await _arabicVoice.initialize()
        : await _voice.initialize();

    if (!initialized) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isSpeaking = false;
      });
      _stopAnim();
      return;
    }

    try {
      if (isArabic) {
        await _arabicVoice.speak(
          "ماذا تريد أن تسمع؟ قل الطقس أو الأخبار.",
        );
        setState(() {
  _isSpeaking = false;
  _isListening = true; 
});

        final answer = await _arabicVoice.listenWhisper(seconds: 5);
        final text = (answer ?? "").toLowerCase();

        if (text.contains("طقس") || text.contains("الطقس")) {
          setState(() {
            _isListening = false;
            _isSpeaking = true;
          });
          await _speakWeather();
        } else if (text.contains("خبر") ||
            text.contains("أخبار") ||
            text.contains("اخبار")) {
          setState(() {
            _isListening = false;
            _isSpeaking = true;
          });
          await _speakNews();
        } else {
          await _arabicVoice.speak(
            "لم أفهم طلبك. يمكنك قول الطقس أو الأخبار.",
          );
        }
      } else {
        await _voice.speak(
          "What would you like to hear? Say weather or news.",
        );
            setState(() {
  _isSpeaking = false;
  _isListening = true; // 
});
        final answer = await _voice.listenWhisper(seconds: 5);
        final text = (answer ?? "").toLowerCase();

        if (text.contains("weather")) {
          setState(() {
            _isListening = false;
            _isSpeaking = true;
          });
          await _speakWeather();
        } else if (text.contains("news")) {
          setState(() {
            _isListening = false;
            _isSpeaking = true;
          });
          await _speakNews();
        } else {
          await _voice.speak(
            "I did not understand. You can say weather or news.",
          );
        }
      }
    } catch (e) {
      if (isArabic) {
        await _arabicVoice.speak("عذرًا، حدثت مشكلة في المساعد الصوتي.");
      } else {
        await _voice.speak(
          "Sorry, there was a problem with the voice assistant.",
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isSpeaking = false;
      });
      _stopAnim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Provider.of<LocaleProvider>(context).isArabic;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: kPrimary,
        title: const Text("Daily Library"),
        titleTextStyle: const TextStyle(
          fontSize: 34,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 42),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 130),
          child: Column(
            children: [
              _buildWeatherCard(isArabic),
              const SizedBox(height: 24),
              _buildNewsCard(isArabic),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: GestureDetector(
        onTap: _startDailyLibraryVoice,
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isListening || _isSpeaking)
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(100, 100),
                      painter: RipplePainter(
                        animation: _rippleController.value,
                        color: _isListening ? Colors.green : Colors.red,
                      ),
                    );
                  },
                ),
              AnimatedBuilder(
                animation: Listenable.merge([
                  _pulseController,
                  _rotateController,
                ]),
                builder: (context, child) {
                  final scale = (_isListening || _isSpeaking)
                      ? 1.0 + (_pulseController.value * 0.15)
                      : 1.0;

                  Color buttonColor;
                  if (_isListening) {
                    buttonColor = Colors.green;
                  } else if (_isSpeaking) {
                    buttonColor = Colors.red;
                  } else {
                    buttonColor = kPrimary;
                  }

                  return Transform.scale(
                    scale: scale,
                    child: Transform.rotate(
                      angle: (_isListening || _isSpeaking)
                          ? _rotateController.value * 2 * math.pi
                          : 0,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              buttonColor,
                              buttonColor.withOpacity(0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: buttonColor.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Icon(
                _isListening
                    ? Icons.mic
                    : _isSpeaking
                        ? Icons.volume_up
                        : Icons.mic_none,
                color: Colors.white,
                size: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCard(bool isArabic) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: kPrimary.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: kPrimary, width: 2),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 230),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              icon: Icons.wb_sunny,
              title: isArabic ? "الطقس" : "Weather",
            ),
            const SizedBox(height: 22),
            if (isLoadingWeather)
              const Center(child: CircularProgressIndicator())
            else if (weatherData == null)
              Text(
                isArabic
                    ? "تعذر تحميل الطقس الآن."
                    : "Unable to load weather right now.",
                style: const TextStyle(fontSize: 22, color: Colors.black87),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${weatherData!['current']['temp_c']}°",
                    style: const TextStyle(
                      fontSize: 58,
                      fontWeight: FontWeight.bold,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weatherData!['customCityName'].toString(),
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: kPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          weatherData!['current']['condition']['text']
                              .toString(),
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(bool isArabic) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: kPrimary.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: kPrimary, width: 2),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 340),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              icon: Icons.article,
              title: isArabic ? "الأخبار" : "News",
            ),
            const SizedBox(height: 20),
            if (isLoadingNews)
              const Center(child: CircularProgressIndicator())
            else if (newsList.isEmpty)
              Text(
                isArabic
                    ? "لا توجد أخبار متاحة الآن."
                    : "No news available right now.",
                style: const TextStyle(fontSize: 22, color: Colors.black87),
              )
            else
              Column(
                children: newsList.take(3).map((news) {
                  return _newsLine(news['title']?.toString() ?? "");
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cardHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 46, color: kPrimary),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.bold,
            color: kPrimary,
          ),
        ),
      ],
    );
  }

  Widget _newsLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Icon(Icons.circle, size: 10, color: kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 21,
                height: 1.35,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double animation;
  final Color color;

  RipplePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (int i = 0; i < 3; i++) {
      final progress = (animation + (i * 0.33)) % 1.0;
      final radius = 40 + (progress * 50);
      final opacity = 1.0 - progress;

      paint.color = color.withOpacity(opacity * 0.6);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.color != color;
  }
}