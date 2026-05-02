import 'package:disaster_response_app/features/user_mobile/domain/sos_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Example - Cách tích hợp SOS vào ứng dụng
/// 
/// Này là một ví dụ đơn giản về cách sử dụng SOS Controller
/// trong một màn hình thực tế

class SOSIntegrationExample extends ConsumerWidget {
  const SOSIntegrationExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sosState = ref.watch(sosControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví Dụ Tích Hợp SOS'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hiển thị trạng thái
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getStatusColor(sosState.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _getStatusText(sosState.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (sosState.message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      sosState.message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (sosState.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lỗi: ${sosState.errorMessage}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Nút SOS nhanh
            ElevatedButton(
              onPressed: sosState.status == SOSStatus.loading
                  ? null
                  : () => _sendQuickSOS(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
              ),
              child: const Text(
                'GỬI SOS NHANH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nút Đặt lại
            OutlinedButton(
              onPressed: () {
                ref.read(sosControllerProvider.notifier).reset();
              },
              child: const Text('Đặt lại'),
            ),
          ],
        ),
      ),
    );
  }

  /// Gửi SOS nhanh với dữ liệu mặc định
  void _sendQuickSOS(BuildContext context, WidgetRef ref) {
    ref.read(sosControllerProvider.notifier).sendSOS(
      userName: 'User Demo',
      phoneNumber: '0912345678',
      latitude: 10.762,
      longitude: 106.660,
      description: 'Cấp cứu',
    );
  }

  /// Lấy màu dựa trên trạng thái
  Color _getStatusColor(SOSStatus status) {
    switch (status) {
      case SOSStatus.idle:
        return Colors.grey;
      case SOSStatus.loading:
        return Colors.blue;
      case SOSStatus.success:
        return Colors.green;
      case SOSStatus.error:
        return Colors.red;
      case SOSStatus.fallbackActivated:
        return Colors.orange;
    }
  }

  /// Lấy text dựa trên trạng thái
  String _getStatusText(SOSStatus status) {
    switch (status) {
      case SOSStatus.idle:
        return 'Chờ gửi SOS';
      case SOSStatus.loading:
        return 'Đang gửi...';
      case SOSStatus.success:
        return 'Gửi thành công ✓';
      case SOSStatus.error:
        return 'Lỗi ✗';
      case SOSStatus.fallbackActivated:
        return 'SMS Fallback Kích hoạt';
    }
  }
}

/// ============================================================
/// HƯỚNG DẪN TÍCH HỢP VÀO ỨNG DỤNG THỰC TẾ
/// ============================================================

/// **CÁCH 1: Thêm nút SOS vào Floating Action Button**
class ExampleMainScreen extends ConsumerWidget {
  const ExampleMainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang Chính')),
      body: const Center(child: Text('Nội dung chính')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Chuyển tới SOS Screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SOSIntegrationExample(),
            ),
          );
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.sos),
      ),
    );
  }
}

/// **CÁCH 2: Thêm nút SOS với Dialog Xác Nhận**
Future<void> showSOSConfirmationDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final sosController = ref.read(sosControllerProvider.notifier);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Gửi SOS?'),
      content: const Text(
        'Bạn chắc chắn muốn gửi SOS khẩn cấp? '
        'Dữ liệu sẽ được gửi đến các cơ quan chức năng.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            sosController.sendSOS(
              userName: 'User',
              phoneNumber: '0912345678',
              latitude: 10.762,
              longitude: 106.660,
              description: 'Cấp cứu',
            );
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Gửi SOS'),
        ),
      ],
    ),
  );
}

/// **CÁCH 3: Tích hợp vào Admin Map Screen**
///
/// Thêm nút SOS khi xem map và biết được vị trí hiện tại:
///
/// ```dart
/// FloatingActionButton(
///   onPressed: () async {
///     // Lấy vị trí từ map controller
///     final center = mapController.camera.center;
///     
///     ref.read(sosControllerProvider.notifier).sendSOS(
///       userName: 'Admin User',
///       phoneNumber: await getUserPhone(),
///       latitude: center.latitude,
///       longitude: center.longitude,
///       description: 'SOS từ Admin Map',
///     );
///   },
///   backgroundColor: Colors.red,
///   child: const Icon(Icons.sos),
/// )
/// ```

/// **CÁCH 4: Tích hợp vào Emergency News Screen**
///
/// Thêm quick SOS button khi xem tin tức khẩn cấp:
///
/// ```dart
/// ListTile(
///   title: const Text('Gửi SOS'),
///   trailing: ElevatedButton.icon(
///     onPressed: () {
///       ref.read(sosControllerProvider.notifier).sendSOS(
///         userName: currentUser.name,
///         phoneNumber: currentUser.phone,
///         latitude: currentLocation.lat,
///         longitude: currentLocation.lon,
///         description: 'SOS từ tin tức khẩn cấp',
///       );
///     },
///     icon: const Icon(Icons.sos),
///     label: const Text('SOS'),
///     style: ElevatedButton.styleFrom(
///       backgroundColor: Colors.red,
///     ),
///   ),
/// )
/// ```
