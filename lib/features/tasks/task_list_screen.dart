import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/providers/providers.dart';
import '../../domain/repositories/task_repository.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskListAsync = ref.watch(allTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks Queue', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allTasksProvider),
          ),
        ],
      ),
      body: taskListAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  Text('No tasks found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _TaskTile(task: task);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error loading tasks: $err', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(allTasksProvider),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskEntity task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade800, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Future: Open task details
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Type
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildTypeIcon(task.type),
              ),
              const SizedBox(width: 16),
              
              // Middle Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Updated: ${_formatDate(task.updatedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                    if (task.type == TaskType.image && (task.payload as Map).containsKey('image_path'))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File((task.payload as Map)['image_path']),
                            height: 60,
                            width: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Status Chip
              _buildStatusBadge(task.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(TaskType type) {
    switch (type) {
      case TaskType.audio:
        return const Icon(Icons.mic, color: Colors.purpleAccent, size: 24);
      case TaskType.image:
        return const Icon(Icons.image, color: Colors.blueAccent, size: 24);
      case TaskType.text:
        return const Icon(Icons.text_fields, color: Colors.orangeAccent, size: 24);
      case TaskType.survey:
        return const Icon(Icons.assignment, color: Colors.greenAccent, size: 24);
    }
  }

  Widget _buildStatusBadge(TaskStatus status) {
    Color color;
    String label;
    switch (status) {
      case TaskStatus.local:
        color = Colors.grey;
        label = 'Local';
        break;
      case TaskStatus.pending:
        color = Colors.orangeAccent;
        label = 'Pending';
        break;
      case TaskStatus.syncing:
        color = Colors.blueAccent;
        label = 'Syncing';
        break;
      case TaskStatus.synced:
        color = Colors.greenAccent;
        label = 'Synced';
        break;
      case TaskStatus.failed:
        color = Colors.redAccent;
        label = 'Failed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  String _formatDate(DateTime date) {
    // simplified formatter avoiding extra locale packages
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
