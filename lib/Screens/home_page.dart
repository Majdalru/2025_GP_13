import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String elderlyName;
  final VoidCallback onTapArrowToMedsSummary;
  final VoidCallback onTapEmergency;

  const HomePage({
    super.key,
    required this.elderlyName,
    required this.onTapArrowToMedsSummary,
    required this.onTapEmergency,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder UI for the caregiver's home page.
    // You can build this out with the actual UI you need.
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Monitoring: $elderlyName',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            title: const Text("Today's Medication Summary"),
            subtitle: const Text("View today's medication status."),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: onTapArrowToMedsSummary,
          ),
        ),
        Card(
          child: ListTile(
            title: const Text("Emergency SOS"),
            subtitle: const Text("View location alerts."),
            tileColor: Colors.red.shade50,
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: onTapEmergency,
          ),
        ),
      ],
    );
  }
}
