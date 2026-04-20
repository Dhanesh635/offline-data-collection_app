import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/task_repository.dart';

class ApiConfig {
  /// Toggle this to [false] when testing on a real device.
  static const bool useEmulator = false;

  /// Replace with your machine's local IP address (e.g., '192.168.1.10')
  /// when running on a physical device.
  /// A real device needs the local IP because it is on its own network
  /// and cannot resolve the host computer via localhost.
  static const String realDeviceIp = '127.0.0.1';

  static String get baseUrl {
    // 10.0.2.2 is a special IP alias used by the Android Emulator
    // to route traffic to the host machine's loopback interface (localhost).
    final url = useEmulator
        ? 'http://10.0.2.2:3000'
        : 'http://$realDeviceIp:3000';

    debugPrint('🌐 Using Base URL: $url');
    return url;
  }
}

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Add basic logging (print request + response)
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  Future<bool> uploadTask(TaskEntity task) async {
    try {
      final response = await _dio.post(
        '/tasks',
        data: {
          'id': task.id,
          'title': task.title,
          'type': task.type.name,
          'payload': task.payload,
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      return false;
    } on DioException catch (e) {
      // Handles network failure, timeout, and server errors
      debugPrint('Dio Error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return false;
    }
  }
}
