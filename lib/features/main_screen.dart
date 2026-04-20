import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/providers/providers.dart';
import '../domain/repositories/task_repository.dart';
import 'dashboard/dashboard_screen.dart';
import 'tasks/task_list_screen.dart';
import 'sync/sync_screen.dart';
import 'widgets/sync_status_banner.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    TaskListScreen(),
    SyncScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Top banner for connectivity & sync status sharing across all tabs
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SyncStatusBanner(),
            Expanded(
              child: _screens[_currentIndex],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.sync_outlined),
            selectedIcon: Icon(Icons.sync),
            label: 'Sync',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? _buildFabMenu(context, ref) : null,
    );
  }

  // FAB menu for adding new tasks (camera capture or text task)
  Widget _buildFabMenu(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Add New Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Capture Image'),
                    onTap: () {
                      Navigator.pop(context);
                      _captureImageTask(context, ref);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add Text Task'),
                    onTap: () {
                      Navigator.pop(context);
                      _addDummyTask(context, ref);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      child: const Icon(Icons.add),
    );
  }

  Future<void> _addDummyTask(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final dummyId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    final dummyTask = TaskEntity(
      id: dummyId,
      title: 'Dummy Task ${DateTime.now().second}',
      type: TaskType.audio,
      status: TaskStatus.pending,
      payload: {'test': true},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await repo.addTask(dummyTask);
      await repo.addLog(dummyId, 'Task created via MainScreen FAB', LogStatus.success);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
      return;
    }

    ref.invalidate(allTasksProvider);
    ref.invalidate(queuedTasksProvider);
  }

  Future<void> _captureImageTask(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final repo = ref.read(repositoryProvider);
    final dummyId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    final imageTask = TaskEntity(
      id: dummyId,
      title: 'Image Task',
      type: TaskType.image,
      status: TaskStatus.pending,
      payload: {'image_path': image.path},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await repo.addTask(imageTask);
      await repo.addLog(dummyId, 'Image task captured', LogStatus.success);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
      return;
    }

    ref.invalidate(allTasksProvider);
    ref.invalidate(queuedTasksProvider);
  }
}
