import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class LocationPage extends StatelessWidget {
  const LocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.location)),
      body: Center(
        child: Text(
          AppLocalizations.of(context)!.comingSoon,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 51, 60, 116),
          ),
        ),
      ),
      //Padding(
      //   padding: const EdgeInsets.all(16),
      //   child: Column(
      //     children: [
      //       Container(
      //         height: 220,
      //         decoration: BoxDecoration(
      //           color: cs.primaryContainer.withOpacity(.5),
      //           borderRadius: BorderRadius.circular(16),
      //         ),
      //         child: const Center(child: Icon(Icons.map, size: 64)),
      //       ),
      //       const SizedBox(height: 16),
      //       const ListTile(
      //         leading: Icon(Icons.place),
      //         title: Text('loc ..........'),
      //       ),
      //       const ListTile(
      //         leading: Icon(Icons.access_time),
      //         title: Text('Time ..........'),
      //       ),
      //     ],
      //   ),
      //),
    );
  }
}
