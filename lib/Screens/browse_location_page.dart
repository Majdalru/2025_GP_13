import 'package:flutter/material.dart';

class BrowseLocationPage extends StatelessWidget {
  const BrowseLocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: color.primaryContainer.withOpacity(.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Icon(Icons.map, size: 64)),
          ),
          const SizedBox(height: 20),
          const _KV(label: 'Location', value: 'Riyadh, KSU - Gate 3'),
          const _KV(label: 'Last update', value: '12:45 PM'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh location'),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;
  const _KV({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value),
      leading: const Icon(Icons.info_outline),
    );
  }
}
