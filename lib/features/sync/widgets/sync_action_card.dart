import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// A card containing the "Start Sync" and "Retry All" action buttons.
/// Used by [SyncScreen] to trigger manual sync cycles.
class SyncActionCard extends StatelessWidget {
  final Future<void> Function(BuildContext context, WidgetRef ref) onSync;

  const SyncActionCard({super.key, required this.onSync});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SyncButton(onSync: onSync),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _RetryAllButton(onSync: onSync),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  final Future<void> Function(BuildContext, WidgetRef) onSync;

  const _SyncButton({required this.onSync});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => ElevatedButton.icon(
        onPressed: () => onSync(context, ref),
        icon: const Icon(Icons.sync),
        label: const Text('Start Sync'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _RetryAllButton extends StatelessWidget {
  final Future<void> Function(BuildContext, WidgetRef) onSync;

  const _RetryAllButton({required this.onSync});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => OutlinedButton.icon(
        onPressed: () => onSync(context, ref), // Same action effectively handles retries
        icon: const Icon(Icons.refresh),
        label: const Text('Retry All'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: Theme.of(context).colorScheme.primary,
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
