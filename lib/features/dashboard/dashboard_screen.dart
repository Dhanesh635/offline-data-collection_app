import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';

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
                _buildStatCard(
                  context: context,
                  label: 'Total Tasks',
                  asyncCount: totalAsync,
                  textColor: Colors.blueAccent,
                  icon: Icons.library_books,
                  iconColor: Colors.blueAccent,
                ),
                _buildStatCard(
                  context: context,
                  label: 'Pending',
                  asyncCount: pendingAsync,
                  textColor: Colors.orangeAccent,
                  icon: Icons.hourglass_empty,
                  iconColor: Colors.orangeAccent,
                ),
                _buildStatCard(
                  context: context,
                  label: 'Synced',
                  asyncCount: syncedAsync,
                  textColor: Colors.greenAccent,
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.greenAccent,
                ),
                _buildStatCard(
                  context: context,
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

  Widget _buildStatCard({
    required BuildContext context,
    required String label,
    required AsyncValue<int> asyncCount,
    required Color textColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      // We rely on the global cardTheme for color and shape, but apply specific gradients or shadows if desired
      elevation: 4,
      shadowColor: iconColor.withValues(alpha: 0.2),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const Spacer(),
            asyncCount.when(
              data: (count) => Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.0,
                ),
              ),
              loading: () => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (err, stack) => const Icon(Icons.error, color: Colors.red),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
