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
  final ArabicVoiceAssistantService _arabicVoice =
      ArabicVoiceAssistantService();

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

    // مكة
    if (lat >= 21 && lat <= 22.5 && lon >= 39 && lon <= 40.5) {
      return isArabic ? 'مكة' : 'Makkah';
    }

    // المدينة
    if (lat >= 24 && lat <= 25.5 && lon >= 39 && lon <= 40.5) {
      return isArabic ? 'المدينة' : 'Madinah';
    }

    // جدة
    if (lat >= 21 && lat <= 22 && lon >= 39 && lon <= 40) {
      return isArabic ? 'جدة' : 'Jeddah';
    }

    // الدمام
    if (lat >= 26 && lat <= 27 && lon >= 49 && lon <= 50) {
      return isArabic ? 'الدمام' : 'Dammam';
    }

    // الخبر
    if (lat >= 26 && lat <= 27 && lon >= 49 && lon <= 50.5) {
      return isArabic ? 'الخبر' : 'Khobar';
    }

    // أبها
    if (lat >= 18 && lat <= 19 && lon >= 42 && lon <= 43) {
      return isArabic ? 'أبها' : 'Abha';
    }

    // تبوك
    if (lat >= 28 && lat <= 29 && lon >= 36 && lon <= 37) {
      return isArabic ? 'تبوك' : 'Tabuk';
    }

    // حائل
    if (lat >= 27 && lat <= 28 && lon >= 41 && lon <= 42) {
      return isArabic ? 'حائل' : 'Hail';
    }

    // القصيم (بريدة)
    if (lat >= 26 && lat <= 27 && lon >= 43 && lon <= 44) {
      return isArabic ? 'القصيم' : 'Qassim';
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
        maxResults: 6,
        category: 'health,science',
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
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final bool isArabic = localeProvider.isArabic;

    // Important: initialize TTS before speaking
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
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final bool isArabic = localeProvider.isArabic;

    //  Important: initialize TTS before speaking
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
      String speech = "أهم عَناوِين الأخبار اليوم: ";
      for (int i = 0; i < newsList.length; i++) {
        speech += "الخَبَر ${i + 1}: ${newsList[i]['title']}. ";
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

    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final bool isArabic = localeProvider.isArabic;

    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    _startAnim();
    HapticFeedback.mediumImpact();

    //  Important: initialize TTS/voice service before speak + listen
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
        await _arabicVoice.speak(" تستطيع السؤال عن الطقس أو الأخبار.");
        setState(() {
          _isSpeaking = false;
          _isListening = true;
        });

        final answer = await _arabicVoice.listenWhisper(seconds: 5);
        final text = (answer ?? "").toLowerCase();

        if (text.contains("طقس") ||
            text.contains("الطقس") ||
            text.contains("جو") ||
            text.contains("الجو") ||
            text.contains("كيف الجو") ||
            text.contains("وش الجو") ||
            text.contains("درجة الحرارة") ||
            text.contains("درجه الحراره") ||
            text.contains("حرارة") ||
            text.contains("حراره")) {
          setState(() {
            _isListening = false;
            _isSpeaking = true;
          });
          await _speakWeather();
        } else if (text.contains("خبر") ||
            text.contains("أخبار") ||
            text.contains("اخبار") ||
            text.contains("الاخبار") ||
            text.contains("الأخبار") ||
            text.contains("وش الاخبار") ||
            text.contains("ايش الاخبار") ||
            text.contains("كيف الاخبار") ||
            text.contains("اهم الاخبار") ||
            text.contains("أهم الأخبار") ||
            text.contains("عناوين الاخبار") ||
            text.contains("عناوين الأخبار") ||
            text.contains("وش فيه اخبار") ||
            text.contains("فيه اخبار") ||
            text.contains("اعطني اخبار") ||
            text.contains("اعطني الاخبار")) {
          setState(() {
            _isListening = false;
            _isSpeaking = true;
          });

          await _speakNews();
        } else {
          await _arabicVoice.speak("لم أفهم طلبك. يمكنك قول الطقس أو الأخبار.");
        }
      } else {
        await _voice.speak("You can ask about weather or news.");
        setState(() {
          _isSpeaking = false;
          _isListening = true; //
        });
        final answer = await _voice.listenWhisper(seconds: 5);
        final text = (answer ?? "").toLowerCase();

        if (text.contains("weather") ||
            text.contains("temperature") ||
            text.contains("forecast") ||
            text.contains("how is the weather") ||
            text.contains("what is the weather")) {
          setState(() {
            _isListening = false;
            _isSpeaking = true;
          });
          await _speakWeather();
        } else if (text.contains("news") ||
            text.contains("latest news") ||
            text.contains("headlines") ||
            text.contains("top news") ||
            text.contains("what's the news") ||
            text.contains("what is the news") ||
            text.contains("how is the news") ||
            text.contains("any news") ||
            text.contains("tell me news") ||
            text.contains("give me news") ||
            text.contains("news today") ||
            text.contains("today's news") ||
            text.contains("what's new")) {
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
    const kTeal = Color(0xFF4DB6AC);
    const kBg = Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 24,
                      color: Color(0xFF1A2340),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'المكتبة اليومية' : 'Daily Library',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                      Text(
                        isArabic
                            ? 'أخبار وطقس اليوم'
                            : 'News & Weather · Today',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable content ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(isArabic ? 'الطقس' : 'Weather'),
                    const SizedBox(height: 8),
                    _buildWeatherCard(isArabic),
                    const SizedBox(height: 20),
                    _sectionLabel(isArabic ? 'أهم العناوين' : 'Top Headlines'),
                    const SizedBox(height: 8),
                    _buildNewsCard(isArabic),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Voice FAB ─────────────────────────────────────────────
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
                    buttonColor = kTeal;
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
                          color: buttonColor,
                          boxShadow: [
                            BoxShadow(
                              color: buttonColor.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic
                              : _isSpeaking
                              ? Icons.volume_up
                              : Icons.mic_none,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.8,
      ),
    );
  }

  IconData _getWeatherIcon(String condition) {
    condition = condition.toLowerCase();

    if (condition.contains('sun') ||
        condition.contains('clear') ||
        condition.contains('مشمس') ||
        condition.contains('صافي')) {
      return Icons.wb_sunny;
    } else if (condition.contains('cloud') ||
        condition.contains('غائم') ||
        condition.contains('ملبد')) {
      return Icons.cloud;
    } else if (condition.contains('rain') || condition.contains('مطر')) {
      return Icons.water_drop;
    } else if (condition.contains('storm') ||
        condition.contains('thunder') ||
        condition.contains('رعد')) {
      return Icons.flash_on;
    } else if (condition.contains('mist') ||
        condition.contains('fog') ||
        condition.contains('ضباب')) {
      return Icons.foggy;
    }

    return Icons.wb_cloudy;
  }

  Color _getWeatherIconColor(String condition) {
    condition = condition.toLowerCase();

    if (condition.contains('sun') ||
        condition.contains('clear') ||
        condition.contains('مشمس') ||
        condition.contains('صافي')) {
      return Colors.orange;
    } else if (condition.contains('cloud') ||
        condition.contains('غائم') ||
        condition.contains('ملبد')) {
      return Colors.blueGrey;
    } else if (condition.contains('rain') || condition.contains('مطر')) {
      return Colors.blue;
    } else if (condition.contains('storm') ||
        condition.contains('thunder') ||
        condition.contains('رعد')) {
      return Colors.deepPurple;
    } else if (condition.contains('mist') ||
        condition.contains('fog') ||
        condition.contains('ضباب')) {
      return Colors.grey;
    }

    return kPrimary;
  }

  String _getWeatherTip(double temp, bool isArabic) {
    if (temp >= 35) {
      return isArabic
          ? "الجو حار اليوم، يُفضل شرب الماء وتجنب الشمس."
          : "It is hot today. Drink water and avoid direct sunlight.";
    } else if (temp <= 15) {
      return isArabic
          ? "الجو بارد اليوم، يُفضل ارتداء ملابس دافئة."
          : "It is cold today. Wearing warm clothes is recommended.";
    }

    return isArabic
        ? "الجو مناسب اليوم، نتمنى لك يومًا لطيفًا."
        : "The weather is pleasant today. Have a nice day.";
  }

  Widget _buildWeatherCard(bool isArabic) {
    final String condition = weatherData == null
        ? ""
        : weatherData!['current']['condition']['text'].toString();

    final double temp = weatherData == null
        ? 0
        : double.tryParse(weatherData!['current']['temp_c'].toString()) ?? 0;

    const kBlueHero = Color(0xFFE3F2FD);
    const kBlueDark = Color(0xFF185FA5);
    const kBlueMid = Color(0xFF378ADD);
    const kBluePale = Color(0xFF90CAF9);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Hero: temp + icon ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: const BoxDecoration(
              color: kBlueHero,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: isLoadingWeather
                ? const Center(child: CircularProgressIndicator())
                : weatherData == null
                ? Text(
                    isArabic
                        ? 'تعذر تحميل الطقس الآن.'
                        : 'Unable to load weather right now.',
                    style: const TextStyle(fontSize: 18, color: kBlueDark),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Temp + condition
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${weatherData!['current']['temp_c']}',
                                  style: const TextStyle(
                                    fontSize: 58,
                                    fontWeight: FontWeight.w300,
                                    color: kBlueDark,
                                    height: 1,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    '°C',
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: kBlueMid,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              condition,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: kBlueDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: kBlueMid,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  weatherData!['customCityName'].toString(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: kBlueMid,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Weather icon circle
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: kBluePale.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getWeatherIcon(condition),
                          size: 38,
                          color: _getWeatherIconColor(condition),
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Stats row ────────────────────────────────────────────
          if (weatherData != null)
            IntrinsicHeight(
              child: Row(
                children: [
                  _statCell(
                    label: isArabic ? 'الرطوبة' : 'Humidity',
                    value: '${weatherData!['current']['humidity']}%',
                  ),
                  _statDivider(),
                  _statCell(
                    label: isArabic ? 'الرياح' : 'Wind',
                    value: '${weatherData!['current']['wind_kph']} km/h',
                  ),
                  _statDivider(),
                  _statCell(
                    label: isArabic ? 'الإحساس' : 'Feels like',
                    value: '${weatherData!['current']['feelslike_c']}°',
                  ),
                ],
              ),
            ),

          // ── Tip row ──────────────────────────────────────────────
          if (weatherData != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                border: const Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    size: 20,
                    color: kBlueMid,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getWeatherTip(temp, isArabic),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF374151),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Read aloud button ─────────────────────────────────────
          GestureDetector(
            onTap: _speakWeather,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: const Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.volume_up_outlined,
                    size: 20,
                    color: kBlueDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'استمع للطقس' : 'Read weather aloud',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kBlueDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell({required String label, required String value}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2340),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 0.5, color: const Color(0xFFE5E7EB));
  }

  Widget _buildNewsCard(bool isArabic) {
    const kBlueDark = Color(0xFF185FA5);
    const kBlueBg = Color(0xFFE6F1FB);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'أخبار اليوم' : "Today's News",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2340),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kBlueBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isArabic ? 'صحة وعلوم' : 'Health & Science',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kBlueDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── News list ─────────────────────────────────────────
          if (isLoadingNews)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (newsList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                isArabic
                    ? 'لا توجد أخبار متاحة الآن.'
                    : 'No news available right now.',
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
            )
          else
            ...newsList.take(6).toList().asMap().entries.map((entry) {
              return _newsTitleLine(
                index: entry.key + 1,
                title: entry.value['title']?.toString() ?? '',
                source: entry.value['source']?.toString(),
                isArabic: isArabic,
              );
            }),

          // ── Read aloud button ─────────────────────────────────
          GestureDetector(
            onTap: _speakNews,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.volume_up_outlined,
                    size: 20,
                    color: kBlueDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'استمع للأخبار' : 'Read headlines aloud',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kBlueDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Remove old _cardHeader — no longer used
  Widget _cardHeader({required IconData icon, required String title}) {
    return const SizedBox.shrink();
  }

  Widget _newsTitleLine({
    required int index,
    required String title,
    String? source,
    bool isArabic = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F1FB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFF185FA5),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A2340),
                  ),
                ),
                if (source != null && source.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    source,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
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
