import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/repositories/task_repository.dart';

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
            _buildActionCard(context, ref),
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
            _buildQueueList(queueAsync),
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
            _buildFailedTasksList(ref, allTasksAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, WidgetRef ref) {
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
                  child: ElevatedButton.icon(
                    onPressed: () => _runSync(context, ref),
                    icon: const Icon(Icons.sync),
                    label: const Text('Start Sync'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _runSync(context, ref), // Same action effectively handles retries
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry All'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
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

  Widget _buildQueueList(AsyncValue<List<SyncQueueEntity>> queueAsync) {
    return queueAsync.when(
      data: (queue) {
        if (queue.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text('Queue is empty.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: queue.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final q = queue[index];
            return Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade800),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.queue, color: Colors.white, size: 20),
                ),
                title: Text('Task ID: ${q.taskId.substring(0, 8)}...'),
                subtitle: Text('Retries: ${q.retryCount} • Status: ${q.status.name}'),
                trailing: q.status == SyncStatus.inProgress
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.hourglass_bottom, color: Colors.orangeAccent),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildFailedTasksList(WidgetRef ref, AsyncValue<List<TaskEntity>> tasksAsync) {
    return tasksAsync.when(
      data: (tasks) {
        final failedTasks = tasks.where((t) => t.status == TaskStatus.failed).toList();
        if (failedTasks.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text('No failed tasks!', style: TextStyle(color: Colors.green)),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: failedTasks.length,
          itemBuilder: (context, index) {
            final task = failedTasks[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
              ),
              child: ListTile(
                leading: Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                title: Text(task.title),
                subtitle: const Text('Failed to sync previously'),
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    // Show logs
                    _showLogsBottomSheet(context, ref, task.id, task.title);
                  },
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showLogsBottomSheet(BuildContext context, WidgetRef ref, String taskId, String taskTitle) {
    ref.invalidate(logsProvider(taskId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.history),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Logs: $taskTitle',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final logsAsync = ref.watch(logsProvider(taskId));
                        return logsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('Error: $e')),
                          data: (logs) {
                            if (logs.isEmpty) {
                              return const Center(child: Text('No logs recorded for this task.'));
                            }
                            return ListView.separated(
                              controller: scrollController,
                              itemCount: logs.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final log = logs[index];
                                final isError = log.status == LogStatus.failed;
                                return ListTile(
                                  leading: Icon(
                                    isError ? Icons.error_outline : Icons.check_circle_outline,
                                    color: isError ? Colors.redAccent : Colors.greenAccent,
                                  ),
                                  title: Text(log.message, style: const TextStyle(fontSize: 14)),
                                  subtitle: Text(
                                    log.timestamp.toString().split('.')[0],
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
