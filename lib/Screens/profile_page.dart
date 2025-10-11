import 'package:flutter/material.dart';
import 'home_page.dart';

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
      onTapArrowToMedsSummary: () {
        // مؤقتًا نخليها فاضية
      },
      onTapEmergency: () {
        // مؤقتًا نخليها فاضية أو نضيف التنقل إلى صفحة الـ Location لاحقًا
      },
    ),
  ),
);


              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Add Profile'),
            ),
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
