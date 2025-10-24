import 'package:flutter/material.dart';

class AudioPlayerPage extends StatelessWidget {
  final String title;
  final String category;

  const AudioPlayerPage({
    super.key,
    required this.title,
    required this.category,
  });

  static const kPrimary = Color(0xFF1B3A52);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // AppBar موحّد مثل الصفحات السابقة
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: kPrimary,
        title: Text(title, overflow: TextOverflow.ellipsis),
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
              // مساحة بسيطة تحت الـAppBar
              const SizedBox(height: 10),

              // بطاقة المشغّل
              Expanded(
                child: Center(
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    shadowColor: kPrimary.withOpacity(0.15),
                    margin: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(color: kPrimary.withOpacity(0.85), width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // العنوان + صورة
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 45,
                                backgroundImage: AssetImage('assets/images/sample.jpg'),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansArabic',
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: kPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // المؤشر (Slider)
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: 0, // UI فقط حالياً
                              onChanged: (_) {},
                              min: 0,
                              max: 100,
                              activeColor: kPrimary,
                              inactiveColor: Colors.grey[300],
                            ),
                          ),

                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "00:00",
                              style: TextStyle(
                                fontFamily: 'NotoSansArabic',
                                fontSize: 20,
                                color: Colors.black54,
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // أزرار التحكم
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous),
                                iconSize: 50,
                                color: kPrimary,
                                onPressed: () {},
                                splashRadius: 30,
                              ),
                              const SizedBox(width: 20),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: const CircleBorder(),
                                  backgroundColor: kPrimary,
                                  padding: const EdgeInsets.all(22),
                                  elevation: 4,
                                ),
                                onPressed: () {},
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 60),
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                icon: const Icon(Icons.skip_next),
                                iconSize: 50,
                                color: kPrimary,
                                onPressed: () {},
                                splashRadius: 30,
                              ),
                            ],
                          ),

                          const SizedBox(height: 35),

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
