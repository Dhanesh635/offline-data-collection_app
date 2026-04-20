import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import 'widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalTasksProvider);
    final pendingAsync = ref.watch(pendingTasksProvider);
    final syncedAsync = ref.watch(syncedTasksProvider);
    final failedAsync = ref.watch(failedTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(
                  label: 'Total Tasks',
                  asyncCount: totalAsync,
                  textColor: Colors.blueAccent,
                  icon: Icons.library_books,
                  iconColor: Colors.blueAccent,
                ),
                StatCard(
                  label: 'Pending',
                  asyncCount: pendingAsync,
                  textColor: Colors.orangeAccent,
                  icon: Icons.hourglass_empty,
                  iconColor: Colors.orangeAccent,
                ),
                StatCard(
                  label: 'Synced',
                  asyncCount: syncedAsync,
                  textColor: Colors.greenAccent,
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.greenAccent,
                ),
                StatCard(
                  label: 'Failed',
                  asyncCount: failedAsync,
                  textColor: Colors.redAccent,
                  icon: Icons.error_outline,
                  iconColor: Colors.redAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
