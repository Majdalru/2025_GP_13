import 'package:flutter/material.dart';

class BrowseSummaryPage extends StatelessWidget {
  const BrowseSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SummaryTile(title: 'Medication', value: '3 taken / 1 missed'),
        _SummaryTile(title: 'Meals', value: '2/3 completed'),
        _SummaryTile(title: 'Steps', value: '2,450'),
        _SummaryTile(title: 'Notes', value: 'Hydrate more • Slept well'),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
