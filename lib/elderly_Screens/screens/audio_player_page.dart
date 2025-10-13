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
    const darkBlue = Color(0xFF2A4D69);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Top Row (Back + Title)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        size: 36, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 🔹 Audio Player Card
              Expanded(
                child: Center(
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    shadowColor: darkBlue.withOpacity(0.15),
                    margin: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(color: darkBlue.withOpacity(0.8), width: 2),
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
                                backgroundImage:
                                    AssetImage('assets/images/sample.jpg'),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansArabic',
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // 🔹 Slider
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 18),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: 0,
                              onChanged: (value) {},
                              min: 0,
                              max: 100,
                              activeColor: darkBlue,
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

                          // 🔹 Player Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous),
                                iconSize: 50,
                                color: darkBlue,
                                onPressed: () {},
                              ),
                              const SizedBox(width: 20),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: const CircleBorder(),
                                  backgroundColor: darkBlue,
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
                                color: darkBlue,
                                onPressed: () {},
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
