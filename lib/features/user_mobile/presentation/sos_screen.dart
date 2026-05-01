import 'package:disaster_response_app/features/user_mobile/domain/sos_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SOS Screen - Màn hình gửi SOS khẩn cấp
class SOSScreen extends ConsumerStatefulWidget {
  const SOSScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends ConsumerState<SOSScreen> {
  final _userNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _userNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosControllerProvider);
    final sosController = ref.read(sosControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gọi SOS Khẩn Cấp'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Icon SOS lớn
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Thông báo trạng thái
            if (sosState.message != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sosState.status == SOSStatus.error
                      ? Colors.red.shade100
                      : sosState.status == SOSStatus.success ||
                              sosState.status == SOSStatus.fallbackActivated
                          ? Colors.green.shade100
                          : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      sosState.status == SOSStatus.error
                          ? Icons.error
                          : sosState.status == SOSStatus.success ||
                                  sosState.status == SOSStatus.fallbackActivated
                              ? Icons.check_circle
                              : Icons.info,
                      color: sosState.status == SOSStatus.error
                          ? Colors.red
                          : sosState.status == SOSStatus.success ||
                                  sosState.status == SOSStatus.fallbackActivated
                              ? Colors.green
                              : Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sosState.message ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (sosState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  sosState.errorMessage ?? '',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),

            // Form nhập thông tin
            TextField(
              controller: _userNameController,
              decoration: InputDecoration(
                labelText: 'Tên của bạn',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Số điện thoại',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Mô tả tình huống',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.description),
                hintText: 'Vd: Cấp cứu, Mất tích, Tai nạn, v.v.',
              ),
            ),
            const SizedBox(height: 24),

            // Nút SOS lớn
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: sosState.status == SOSStatus.loading
                    ? null
                    : () {
                        if (_userNameController.text.isEmpty ||
                            _phoneController.text.isEmpty ||
                            _descriptionController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Vui lòng điền đầy đủ thông tin'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        sosController.sendSOS(
                          userName: _userNameController.text,
                          phoneNumber: _phoneController.text,
                          description: _descriptionController.text,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: Text(
                  sosState.status == SOSStatus.loading
                      ? 'Đang gửi...'
                      : 'GỬI SOS NGAY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nút Reset
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  sosController.reset();
                  _userNameController.clear();
                  _phoneController.clear();
                  _descriptionController.clear();
                },
                child: const Text('Làm mới'),
              ),
            ),
            const SizedBox(height: 24),

            // Thông tin về SMS Fallback
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Thông tin quan trọng',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Nếu có kết nối mạng: SOS sẽ gửi lên máy chủ\n'
                    '• Nếu không có mạng: Ứng dụng sẽ tự động gửi SMS\n'
                    '• SMS chứa vị trí GPS của bạn\n'
                    '• Các SMS khẩn cấp sẽ được gửi đến 113, 114, 115',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
