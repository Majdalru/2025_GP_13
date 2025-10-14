import 'package:flutter/material.dart';
import 'home_page.dart';
import '/medmain.dart'; // 👈 1. Import Medmain page
import 'meds_summary_page.dart'; // 👈 2. Import Summary page
import 'location_page.dart'; // 👈 3. Import Location page (for emergency)

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Guest', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            const Text('Profiles:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            ListTile(
              title: const Text('Elderly Name 1'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomePage(
                      elderlyName: 'Elderly Name 1',
                      // This is for the "Monthly Overview" link
                      onTapArrowToMedsSummary: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MedsSummaryPage(),
                          ),
                        );
                      },
                      // 👇 4. ADD THE MISSING PARAMETER HERE
                      onTapArrowToMedmain: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Medmain()),
                        );
                      },
                      // This is for the emergency button
                      onTapEmergency: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LocationPage(),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () {}, child: const Text('Add Profile')),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
