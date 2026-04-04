import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';
import '../../services/news_service.dart';
import 'media_page.dart';
import 'elderly_med.dart';

import 'favorites_manager.dart';
import '../../Screens/login_page.dart';

import '../../widgets/floating_voice_button.dart';
import '../../widgets/arabic_floating_voice_button.dart';

import '../../services/voice_assistant_service.dart';
import '../../services/arabic_voice_assistant_service.dart';

import '../../providers/locale_provider.dart';
import 'package:flutter_application_1/models/voice_command.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

/// =====================
///  Styles (Unified)
/// =====================
const kPrimary = Color(0xFF1B3A52);
const kAccentRed = Color(0xFFD62828);
const kSurface = Color(0xFFF5F5F5);
const kCardRadius = 16.0;
const kFieldRadius = 14.0;

const kTitleText = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w800,
  color: kPrimary,
);

const kBodyText = TextStyle(fontSize: 22, color: Colors.black87);

const kButtonText = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

InputDecoration kInput(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(
    fontSize: 20,
    color: kPrimary,
    fontWeight: FontWeight.w600,
  ),
  filled: true,
  fillColor: Colors.white,
  focusedBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: kPrimary, width: 2),
    borderRadius: BorderRadius.circular(kFieldRadius),
  ),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(kFieldRadius)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
);

ButtonStyle kBigButton(Color bg, {EdgeInsets? pad}) => ElevatedButton.styleFrom(
  backgroundColor: bg,
  padding: pad ?? const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  elevation: 4,
);

class ElderlyHomePage extends StatefulWidget {
  const ElderlyHomePage({super.key});

  @override
  State<ElderlyHomePage> createState() => _ElderlyHomePageState();
}

class _ElderlyHomePageState extends State<ElderlyHomePage> {
  String? fullName;
  // news
  final newsService = NewsService();

Future<void> getNews() async {
  try {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final bool isArabic = localeProvider.isArabic;

    final news = await newsService.getTopHeadlines(
      languageCode: isArabic ? 'ar' : 'en',
      country: isArabic ? 'sa' : null,
      maxResults: 3,
      category: 'health',
    );

    if (news.isEmpty) {
      if (isArabic) {
        await _arabicVoice.speak("عذرًا، لم أجد أخبارًا الآن.");
      } else {
        await _voice.speak("Sorry, I could not find any news right now.");
      }
      return;
    }

    if (isArabic) {
      String speech = "أهم الأخبار اليوم: ";
      for (int i = 0; i < news.length; i++) {
        speech += "الخبر ${i + 1}: ${news[i]['title']}. ";
      }
      await _arabicVoice.speak(speech);
    } else {
      String speech = "Here are today's top news headlines. ";
      for (int i = 0; i < news.length; i++) {
        speech += "News ${i + 1}: ${news[i]['title']}. ";
      }
      await _voice.speak(speech);
    }
  } catch (e) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final bool isArabic = localeProvider.isArabic;

    if (isArabic) {
      await _arabicVoice.speak("عذرًا، حدثت مشكلة أثناء جلب الأخبار.");
    } else {
      await _voice.speak("Sorry, there was a problem fetching the news.");
    }
  }
}
// done 
final locationService = LocationService();
final weatherService = WeatherService();
String getSaudiCity(double lat, double lon, bool isArabic) {
  // الرياض
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

  // fallback
  return isArabic ? 'منطقتك' : 'your location';
}
Future<void> getWeather() async {
  try {
    final position = await locationService.getCurrentLocation();

    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final bool isArabic = localeProvider.isArabic;
    final lang = isArabic ? 'ar' : 'en';

    final weather = await weatherService.getCurrentWeather(
      lat: position.latitude,
      lon: position.longitude,
      lang: lang,
    );

    final city =  getSaudiCity(
  position.latitude,
  position.longitude,
  isArabic,
);
    final temp = weather['current']['temp_c'];
    final condition = weather['current']['condition']['text'];

    if (isArabic) {
      await _arabicVoice.speak(
        "الطقس اليوم في $city، $condition، ودرجة الحرارة $temp درجة مئوية",
      );
    } else {
      await _voice.speak(
        "Today's weather in $city is $condition with a temperature of $temp degrees Celsius",
      );
    }
  } catch (e) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final bool isArabic = localeProvider.isArabic;

    if (isArabic) {
      await _arabicVoice.speak("عذرًا، لم أتمكن من جلب الطقس الآن.");
    } else {
      await _voice.speak("Sorry, I couldn't get the weather right now.");
    }
  }
}
  String _translateGender(String? g) {
    if (g == null || g.isEmpty) {
      return AppLocalizations.of(context)!.na;
    }

    switch (g.toLowerCase()) {
      case 'male':
        return AppLocalizations.of(context)!.male;
      case 'female':
        return AppLocalizations.of(context)!.female;
      default:
        return g;
    }
  }

  String? gender;
  String? phone;
  List<String> caregiverNames = [];
  bool loading = true;

  final VoiceAssistantService _voice = VoiceAssistantService();
  final ArabicVoiceAssistantService _arabicVoice =
      ArabicVoiceAssistantService();

  StreamSubscription<DocumentSnapshot>? _userSub;
  int _prevCaregiverCount = 0;
  bool _initialCaregiverLoaded = false;
  bool _didRunNewsTest = false;
  @override
  void initState() {
    super.initState();
    _listenToUserDoc();
    favoritesManager.init();
  }
 
  //here test news

  void _showTopBanner(
    String message, {
    Color color = kPrimary,
    int seconds = 5,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: color,
          elevation: 4,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: const [SizedBox.shrink()],
        ),
      );

    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) {
        messenger.hideCurrentMaterialBanner();
      }
    });
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final out = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      out.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return out;
  }

  void _listenToUserDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (doc) async {
            if (!doc.exists) {
              if (mounted) {
                setState(() => loading = false);
              }
              return;
            }

            final data = doc.data() as Map<String, dynamic>;

            final first = (data['firstName'] ?? '').toString().trim();
            final last = (data['lastName'] ?? '').toString().trim();
            final newFullName =
                [first, last].where((s) => s.isNotEmpty).join(' ');
            final newGender = (data['gender'] ?? '').toString();
            final newPhone = (data['phone'] ?? '').toString();

            final ids = (data['caregiverIds'] is List)
                ? List<String>.from(data['caregiverIds'])
                : <String>[];

            final names = <String>[];

            if (ids.isNotEmpty) {
              for (final batch in _chunk(ids, 10)) {
                final qs = await FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: batch)
                    .get();

                for (final d in qs.docs) {
                  final x = d.data();
                  final f = (x['firstName'] ?? '').toString().trim();
                  final l = (x['lastName'] ?? '').toString().trim();
                  final email = (x['email'] ?? '').toString().trim();
                  final n = [f, l].where((s) => s.isNotEmpty).join(' ');
                  names.add(
                    n.isNotEmpty ? n : (email.isNotEmpty ? email : 'Unknown'),
                  );
                }
              }
            }

            final newCount = names.length;

            if (!_initialCaregiverLoaded) {
              _prevCaregiverCount = newCount;
              _initialCaregiverLoaded = true;
            } else {
              if (mounted) {
                if (newCount > _prevCaregiverCount) {
                  _showTopBanner(
                    AppLocalizations.of(context)!.newCaregiverLinked,
                    color: Colors.green.shade700,
                  );
                } else if (newCount < _prevCaregiverCount) {
                  _showTopBanner(
                    AppLocalizations.of(context)!.caregiverUnlinked,
                    color: kAccentRed,
                  );
                }
              }
              _prevCaregiverCount = newCount;
            }

            if (!mounted) return;

            setState(() {
              fullName = newFullName;
              gender = newGender;
              phone = newPhone;
              caregiverNames = names;
              loading = false;
            });
          },
          onError: (e) {
            if (mounted) {
              setState(() => loading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(
                      context,
                    )!.errorLoadingProfile(e.toString()),
                  ),
                ),
              );
            }
          },
        );
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: kSurface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final localeProvider = Provider.of<LocaleProvider>(context);
    final bool isArabic = localeProvider.isArabic;

    return Scaffold(
      backgroundColor: kSurface,
      drawer: Drawer(
        backgroundColor: kSurface,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          children: [
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  (fullName?.isNotEmpty ?? false)
                      ? fullName!
                      : AppLocalizations.of(context)!.userFallback,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.elderlyInfo,
                          style: kTitleText,
                        ),
                        IconButton(
                          iconSize: 32,
                          splashRadius: 28,
                          icon: const Icon(Icons.settings, color: kPrimary),
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => _EditInfoDialog(
                                initialName: fullName ?? '',
                                initialGender: gender ?? '',
                                initialPhone: phone ?? '',
                                onSave: (newName, newGender, newPhone) async {
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    final parts = newName.split(RegExp(r'\s+'));
                                    final first = parts.isNotEmpty
                                        ? parts.first
                                        : '';
                                    final last = parts.length > 1
                                        ? parts.sublist(1).join(' ')
                                        : '';

                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .update({
                                          'firstName': first,
                                          'lastName': last,
                                          'gender': newGender,
                                          'phone': newPhone,
                                        });

                                    setState(() {
                                      fullName = newName;
                                      gender = newGender;
                                      phone = newPhone;
                                    });

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      if (context.mounted) {
                                        _showTopBanner(
                                          AppLocalizations.of(
                                            context,
                                          )!.informationUpdatedSuccessfully,
                                          color: Colors.green.shade700,
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InfoBox(
                      label: AppLocalizations.of(context)!.name,
                      value: (fullName?.isNotEmpty ?? false)
                          ? fullName!
                          : AppLocalizations.of(context)!.na,
                    ),
                    const SizedBox(height: 14),
                    _InfoBox(
                      label: AppLocalizations.of(context)!.gender,
                      value: _translateGender(gender),
                    ),
                    const SizedBox(height: 14),
                    _InfoBox(
                      label: AppLocalizations.of(context)!.mobile,
                      value: phone ?? AppLocalizations.of(context)!.na,
                    ),
                  ],
                ),
              ),
            ),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _CaregiversBox(names: caregiverNames),
              ),
            ),

            const SizedBox(height: 14),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.verificationCode,
                      style: kTitleText,
                    ),
                    const SizedBox(height: 12),
                    const _PairingCodeBox(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(
                        Icons.menu,
                        size: 42,
                        color: Colors.black,
                      ),
                      splashRadius: 28,
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),

                  isArabic
                      ? ArabicFloatingVoiceButton(
                          onCommand: (command) async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;

                            debugPrint(
                              '🎯 Arabic voice command received in ElderlyHomePage: $command',
                            );

                            switch (command) {
                              case VoiceCommand.goToMedication:
                                if (uid != null) {
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ElderlyMedicationPage(
                                        elderlyId: uid,
                                      ),
                                    ),
                                  );
                                } else {
                                  await _arabicVoice.speak(
                                    'لم أتمكن من العثور على حسابك. يرجى تسجيل الدخول مرة أخرى.',
                                  );
                                }
                                break;

                              case VoiceCommand.addMedication:
                                if (uid == null) {
                                  await _arabicVoice.speak(
                                    'لم أتمكن من العثور على حسابك. يرجى تسجيل الدخول مرة أخرى.',
                                  );
                                  return;
                                }
                                await _arabicVoice.speak(
                                  'حسنًا، سأساعدك في إضافة دواء جديد.',
                                );
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ElderlyMedicationPage(
                                      elderlyId: uid,
                                      initialCommand:
                                          VoiceCommand.addMedication,
                                    ),
                                  ),
                                );
                                break;

                              case VoiceCommand.editMedication:
                                if (uid == null) {
                                  await _arabicVoice.speak(
                                    'لم أتمكن من العثور على حسابك. يرجى تسجيل الدخول مرة أخرى.',
                                  );
                                  return;
                                }
                                await _arabicVoice.speak(
                                  'حسنًا، لنعدّل أحد أدويتك.',
                                );
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ElderlyMedicationPage(
                                      elderlyId: uid,
                                      initialCommand:
                                          VoiceCommand.editMedication,
                                    ),
                                  ),
                                );
                                break;

                              case VoiceCommand.deleteMedication:
                                if (uid == null) {
                                  await _arabicVoice.speak(
                                    'لم أتمكن من العثور على حسابك. يرجى تسجيل الدخول مرة أخرى.',
                                  );
                                  return;
                                }
                                await _arabicVoice.speak(
                                  'حسنًا، لنحدد الدواء الذي تريد حذفه.',
                                );
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ElderlyMedicationPage(
                                      elderlyId: uid,
                                      initialCommand:
                                          VoiceCommand.deleteMedication,
                                    ),
                                  ),
                                );
                                break;

                              case VoiceCommand.goToMedia:
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MediaPage(),
                                  ),
                                );
                                break;

                              case VoiceCommand.goToHome:
                                await _arabicVoice.speak(
                                  'أنت بالفعل في الصفحة الرئيسية.',
                                );
                                break;

                              case VoiceCommand.weather:
                                 await getWeather();
                                break;

                              case VoiceCommand.news:
                                await getNews();
                                  break;

                              case VoiceCommand.sos:
                                if (!mounted) return;
                                await _arabicVoice.speak(
                                  AppLocalizations.of(context)!.voiceSosPreamble,
                                );
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.emergencyTitle,
                                      ),
                                      content: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.emergencyFlowDesc,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            AppLocalizations.of(context)!.ok,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                break;

                              case VoiceCommand.goToSettings:
                                await _arabicVoice.speak(
                                  'صفحة الإعدادات غير جاهزة الآن. لاحقًا سأتمكن من فتحها لك من هنا.',
                                );
                                break;
                            }
                          },
                        )
                      : FloatingVoiceButton(
                          onCommand: (command) async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;

                            debugPrint(
                              '🎯 Voice command received in ElderlyHomePage: $command',
                            );

                            switch (command) {
                              case VoiceCommand.goToMedication:
                                if (uid != null) {
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ElderlyMedicationPage(
                                        elderlyId: uid,
                                      ),
                                    ),
                                  );
                                } else {
                                  await _voice.speak(
                                    "I could not find your account. Please log in again.",
                                  );
                                }
                                break;

                              case VoiceCommand.addMedication:
                                if (uid == null) {
                                  await _voice.speak(
                                    "I could not find your account. Please log in again.",
                                  );
                                  return;
                                }
                                await _voice.speak(
                                  "Okay, I will help you add a new medication.",
                                );
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ElderlyMedicationPage(
                                      elderlyId: uid,
                                      initialCommand:
                                          VoiceCommand.addMedication,
                                    ),
                                  ),
                                );
                                break;

                              case VoiceCommand.editMedication:
                                if (uid == null) {
                                  await _voice.speak(
                                    "I could not find your account. Please log in again.",
                                  );
                                  return;
                                }
                                await _voice.speak(
                                  "Okay, let us edit one of your medications.",
                                );
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ElderlyMedicationPage(
                                      elderlyId: uid,
                                      initialCommand:
                                          VoiceCommand.editMedication,
                                    ),
                                  ),
                                );
                                break;

                              case VoiceCommand.deleteMedication:
                                if (uid == null) {
                                  await _voice.speak(
                                    "I could not find your account. Please log in again.",
                                  );
                                  return;
                                }
                                await _voice.speak(
                                  "Okay, let us choose which medication to delete.",
                                );
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ElderlyMedicationPage(
                                      elderlyId: uid,
                                      initialCommand:
                                          VoiceCommand.deleteMedication,
                                    ),
                                  ),
                                );
                                break;

                              case VoiceCommand.goToMedia:
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MediaPage(),
                                  ),
                                );
                                break;

                              case VoiceCommand.goToHome:
                                await _voice.speak(
                                  "You are already on the home page.",
                                );
                                break;

                              case VoiceCommand.weather:
                                await getWeather();
                               break;

                              case VoiceCommand.news:
                               await getNews();
                               break;

                              case VoiceCommand.sos:
                                if (!mounted) return;
                                await _voice.speak(
                                  AppLocalizations.of(context)!.voiceSosPreamble,
                                );
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.emergencyTitle,
                                      ),
                                      content: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.emergencyFlowDesc,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            AppLocalizations.of(context)!.ok,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                break;

                              case VoiceCommand.goToSettings:
                                await _voice.speak(
                                  "Settings page is not ready yet. In the future, I will open it for you from here.",
                                );
                                break;
                            }
                          },
                        ),

                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.black,
                      size: 36,
                    ),
                    splashRadius: 28,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                            side: const BorderSide(color: kPrimary, width: 2),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.confirmLogout,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: kPrimary,
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 30,
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      AppLocalizations.of(context)!.no,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        color: kPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  ElevatedButton(
                                    style: kBigButton(
                                      kAccentRed,
                                      pad: const EdgeInsets.symmetric(
                                        horizontal: 36,
                                        vertical: 18,
                                      ),
                                    ),
                                    onPressed: () {
                                      FirebaseAuth.instance.signOut();
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginPage(),
                                        ),
                                        (_) => false,
                                      );
                                    },
                                    child: Text(
                                      AppLocalizations.of(context)!.yes,
                                      style: kButtonText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 65),
              Text(
                AppLocalizations.of(
                  context,
                )!.helloUser(fullName?.split(' ').first ?? ''),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 6, 10, 65),
                ),
              ),
              const SizedBox(height: 55),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentRed,
                  minimumSize: const Size(double.infinity, 100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 6,
                ),
                onPressed: () => HapticFeedback.heavyImpact(),
                child: Text(
                  AppLocalizations.of(context)!.sos,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: _HomeCard(
                      icon: Icons.video_library,
                      title: AppLocalizations.of(context)!.media,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MediaPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _HomeCard(
                      icon: Icons.medical_services,
                      title: AppLocalizations.of(context)!.medication,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ElderlyMedicationPage(elderlyId: uid),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.errorNotLoggedIn2,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: kTitleText),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: kPrimary.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(value, style: kBodyText),
        ),
      ],
    );
  }
}

class _CaregiversBox extends StatelessWidget {
  final List<String> names;

  const _CaregiversBox({required this.names});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.caregivers, style: kTitleText),
        const SizedBox(height: 8),
        if (names.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: kPrimary.withOpacity(0.5), width: 1.5),
            ),
            child: Text(
              AppLocalizations.of(context)!.noCaregiversLinked,
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),
          )
        else
          Column(
            children: names.map((name) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: kPrimary.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person,
                      color: Color.fromARGB(255, 27, 108, 113),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _PairingCodeBox extends StatefulWidget {
  const _PairingCodeBox();

  @override
  State<_PairingCodeBox> createState() => _PairingCodeBoxState();
}

class _PairingCodeBoxState extends State<_PairingCodeBox> {
  String? _code;
  Timer? _timer;
  int _countdown = 300;
  bool _isLoading = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdown = 300;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _code = null);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _generateNewCode() async {
    setState(() => _isLoading = true);
    HapticFeedback.selectionClick();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.youNeedToBeLoggedIn),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final newCode = List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'pairingCode': newCode,
            'pairingCodeCreatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() {
          _code = newCode;
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorGeneratingCode(e.toString()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_code != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: kPrimary.withOpacity(0.6), width: 1.5),
            ),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Text(
                  _code!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expires in: ${_formatDuration(_countdown)}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        const SizedBox(height: 15),
        ElevatedButton(
          style: kBigButton(
            const Color.fromARGB(255, 61, 137, 113),
            pad: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          ),
          onPressed: _isLoading ? null : _generateNewCode,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  AppLocalizations.of(context)!.generateCode,
                  style: kButtonText,
                ),
        ),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = (width / 200).clamp(0.8, 1.0);
        final iconSize = 79 * scale;
        final fontSize = 27 * scale;
        final vPadding = 50 * scale;

        return Card(
          color: kSurface,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: kPrimary, width: 2),
          ),
          shadowColor: Colors.grey.withOpacity(0.1),
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: onTap,
            splashColor: kPrimary.withOpacity(0.15),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: vPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: iconSize, color: kPrimary),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: kPrimary,
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
}

class _EditInfoDialog extends StatefulWidget {
  final String initialName;
  final String initialGender;
  final String initialPhone;
  final Function(String name, String gender, String phone) onSave;

  const _EditInfoDialog({
    required this.initialName,
    required this.initialGender,
    required this.initialPhone,
    required this.onSave,
  });

  @override
  State<_EditInfoDialog> createState() => _EditInfoDialogState();
}

class _EditInfoDialogState extends State<_EditInfoDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late String _selectedGender;
  final _formKey = GlobalKey<FormState>();

  String? _phoneUsedError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _selectedGender = widget.initialGender.isNotEmpty
        ? widget.initialGender
        : 'male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<bool> _isPhoneAvailable(String phone) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return true;

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      return snap.docs.first.id == currentUid;
    } catch (e) {
      debugPrint('⚠️ phone uniqueness check failed: $e');
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF9FAFB),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: kPrimary.withOpacity(0.3), width: 2),
      ),
      title: Text(
        AppLocalizations.of(context)!.editInformation,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: kPrimary,
        ),
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: kBodyText,
                  decoration: kInput(
                    AppLocalizations.of(context)!.name,
                  ).copyWith(errorStyle: const TextStyle(fontSize: 18)),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? AppLocalizations.of(context)!.nameIsRequired
                      : null,
                ),
                const SizedBox(height: 18),

                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: kInput(
                    AppLocalizations.of(context)!.gender,
                  ).copyWith(
                    filled: true,
                    fillColor: Colors.white,
                    errorStyle: const TextStyle(fontSize: 18),
                  ),
                  dropdownColor: Colors.white,
                  style: kBodyText,
                  items: [
                    DropdownMenuItem(
                      value: "male",
                      child: Text(
                        AppLocalizations.of(context)!.male,
                        style: kBodyText,
                      ),
                    ),
                    DropdownMenuItem(
                      value: "female",
                      child: Text(
                        AppLocalizations.of(context)!.female,
                        style: kBodyText,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedGender = val ?? 'male';
                    });
                  },
                  validator: (v) => v == null || v.isEmpty
                      ? AppLocalizations.of(context)!.selectGender
                      : null,
                ),
                const SizedBox(height: 18),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: kBodyText,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: kInput(
                    AppLocalizations.of(context)!.mobileFormatHint,
                  ).copyWith(errorStyle: const TextStyle(fontSize: 18)),
                  validator: (v) {
                    final txt = (v ?? "").trim();
                    if (txt.isEmpty) {
                      return AppLocalizations.of(context)!.requiredField;
                    }
                    if (!txt.startsWith('05')) {
                      return AppLocalizations.of(context)!.startWith05;
                    }
                    if (txt.length != 10) {
                      return AppLocalizations.of(context)!.enter10Digits;
                    }
                    if (_phoneUsedError != null) {
                      return _phoneUsedError;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: kPrimary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: const TextStyle(
                      fontSize: 22,
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: kBigButton(
                    kPrimary,
                    pad: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ).copyWith(elevation: const WidgetStatePropertyAll(2)),
                  onPressed: () async {
                    setState(() => _phoneUsedError = null);

                    if (!_formKey.currentState!.validate()) return;

                    final phone = _phoneController.text.trim();

                    final available = await _isPhoneAvailable(phone);
                    if (!available) {
                      if (!mounted) return;
                      setState(() {
                        _phoneUsedError =
                            AppLocalizations.of(context)!.mobileAlreadyUsed;
                      });
                      _formKey.currentState!.validate();
                      return;
                    }

                    widget.onSave(
                      _nameController.text.trim(),
                      _selectedGender,
                      phone,
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context)!.save,
                    style: kButtonText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}