import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import 'widgets/sync_action_card.dart';
import 'widgets/sync_queue_list.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(queuedTasksProvider);
    final allTasksAsync = ref.watch(allTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Engine', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action Buttons
            SyncActionCard(onSync: _runSync),
            const SizedBox(height: 24),

            // Queue Section
            Text(
              'Active Queue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            SyncQueueList(queueAsync: queueAsync),
            const SizedBox(height: 24),

            // Failed Tasks Section
            Text(
              'Failed Synced Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            SyncFailedTasksList(tasksAsync: allTasksAsync),
          ],
        ),
      ),
    );
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync started...'), duration: Duration(seconds: 1)),
    );

    final syncService = ref.read(syncServiceProvider);
    final result = await syncService.syncTasks();

    if (!context.mounted) return;

    ref.invalidate(queuedTasksProvider);
    ref.invalidate(allTasksProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.toString()),
        backgroundColor: result.isFullSuccess
            ? Colors.green.shade700
            : result.hasFailures
                ? Colors.orange.shade700
                : null,
      ),
    );
  }
}
