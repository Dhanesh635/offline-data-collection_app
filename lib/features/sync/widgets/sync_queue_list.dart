import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../domain/repositories/task_repository.dart';

// ============================================================
// SyncQueueList — displays the active sync queue
// ============================================================

/// Renders the list of tasks currently in the sync queue.
class SyncQueueList extends StatelessWidget {
  final AsyncValue<List<SyncQueueEntity>> queueAsync;

  const SyncQueueList({super.key, required this.queueAsync});

  @override
  Widget build(BuildContext context) {
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
}

// ============================================================
// SyncFailedTasksList — displays permanently failed tasks
// ============================================================

/// Renders the list of tasks that have permanently failed sync,
/// with a tap action to view per-task sync logs.
class SyncFailedTasksList extends StatelessWidget {
  final AsyncValue<List<TaskEntity>> tasksAsync;

  const SyncFailedTasksList({super.key, required this.tasksAsync});

  @override
  Widget build(BuildContext context) {
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
                    showSyncLogsBottomSheet(context, task.id, task.title);
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
}

// ============================================================
// showSyncLogsBottomSheet — per-task log viewer
// ============================================================

/// Shows a draggable bottom sheet displaying sync logs for a specific task.
void showSyncLogsBottomSheet(
  BuildContext context,
  String taskId,
  String taskTitle,
) {
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
