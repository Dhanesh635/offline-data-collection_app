import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/providers/providers.dart';

/// Top-of-screen banner that reflects current network state and last sync time.
/// Displayed by [MainScreen] above all navigation tabs.
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final isOffline = snapshot.data?.every((r) => r == ConnectivityResult.none) ?? false;
        final lastSyncAsync = ref.watch(lastSyncTimeProvider);

        return Container(
          color: isOffline ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                isOffline ? Icons.wifi_off : Icons.cloud_sync,
                size: 16,
                color: isOffline
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOffline ? 'Offline Mode' : 'Online • Ready to Sync',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOffline
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              lastSyncAsync.when(
                data: (time) => Text(
                  time == null ? 'Never synced' : 'Last sync: ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: isOffline ? Theme.of(context).colorScheme.onErrorContainer : Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
