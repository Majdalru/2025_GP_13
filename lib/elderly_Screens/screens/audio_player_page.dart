import 'package:flutter/material.dart';

class AudioPlayerPage extends StatelessWidget {
  final String title;
  final String category;

  const AudioPlayerPage({
    super.key,
    required this.title,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFFDFEFE);
    const appBarColor = Color(0xFF2C3E50);
    const textColor = Color(0xFF34495E);
    const accentColor = Color(0xFF2C3E50);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 3,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 36, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        toolbarHeight: 80,
      ),
      body: Center(
        child: Card(
          color: Colors.white,
          elevation: 3,
          shadowColor: Colors.grey.withOpacity(0.1),
          margin: const EdgeInsets.all(25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        style: const TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 18),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: 0,
                    onChanged: (value) {},
                    min: 0,
                    max: 100,
                    activeColor: accentColor,
                    inactiveColor: Colors.grey[300],
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "00:00",
                    style: TextStyle(
                      fontFamily: 'NotoSansArabic',
                      fontSize: 22,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      iconSize: 50,
                      color: accentColor,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.all(22),
                        elevation: 4,
                      ),
                      onPressed: () {},
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      iconSize: 50,
                      color: accentColor,
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  "Tap play to start listening",
                  style: TextStyle(
                    fontFamily: 'NotoSansArabic',
                    fontSize: 22,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
