// lib/features/rescue_stations/presentation/admin_rescue_stations_screen.dart

import 'dart:convert';

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/event_dashboard_screen.dart';
import 'package:disaster_response_app/features/rescue_stations/domain/rescue_station_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminRescueStationsScreen extends ConsumerWidget {
  const AdminRescueStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(rescueStationControllerProvider);

    return stationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Lỗi tải trạm cứu hộ: $err',
          style: const TextStyle(color: AppColors.brandRed),
        ),
      ),
      data: (stations) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Quản lý trạm cứu hộ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _onCreate(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm trạm mới'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Quản lý thông tin trạm, vị trí, liên hệ và năng lực tiếp nhận.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              if (stations.isEmpty)
                _EmptyPanel(onCreate: () => _onCreate(context, ref))
              else
                _StationsTable(
                  stations: stations,
                  onEdit: (station) => _onEdit(context, ref, station),
                  onDelete: (station) => _onDelete(context, ref, station),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onCreate(BuildContext context, WidgetRef ref) async {
    final formData = await showDialog<_RescueStationFormData>(
      context: context,
      builder: (_) => const _RescueStationFormDialog(),
    );

    if (formData == null) return;

    try {
      await ref
          .read(rescueStationControllerProvider.notifier)
          .createStation(
            name: formData.name,
            latitude: formData.latitude,
            longitude: formData.longitude,
            address: formData.address,
            contactPhone: formData.contactPhone,
            capacity: formData.capacity,
            resourcesJson: jsonEncode(formData.resources),
            status: formData.status,
          );

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã tạo trạm cứu hộ.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  Future<void> _onEdit(
    BuildContext context,
    WidgetRef ref,
    RescueStation station,
  ) async {
    final formData = await showDialog<_RescueStationFormData>(
      context: context,
      builder: (_) => _RescueStationFormDialog(existing: station),
    );

    if (formData == null) return;

    try {
      await ref
          .read(rescueStationControllerProvider.notifier)
          .updateStation(
            id: station.id,
            name: formData.name,
            latitude: formData.latitude,
            longitude: formData.longitude,
            address: formData.address,
            contactPhone: formData.contactPhone,
            capacity: formData.capacity,
            resourcesJson: jsonEncode(formData.resources),
            status: formData.status,
          );

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật trạm cứu hộ.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    RescueStation station,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa trạm cứu hộ?'),
        content: Text(
          'Trạm "${station.name}" sẽ được đánh dấu ngưng hoạt động '
          '(soft delete) và có thể đồng bộ lại khi có mạng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(rescueStationControllerProvider.notifier)
          .softDeleteStation(station.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa trạm cứu hộ.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }
}

class _EmptyPanel extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyPanel({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.home_work_outlined,
            size: 44,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa có trạm cứu hộ nào',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thêm trạm đầu tiên để người dân có thể định tuyến đến điểm hỗ trợ gần nhất.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm trạm cứu hộ'),
          ),
        ],
      ),
    );
  }
}

class _StationsTable extends StatelessWidget {
  final List<RescueStation> stations;
  final ValueChanged<RescueStation> onEdit;
  final ValueChanged<RescueStation> onDelete;

  const _StationsTable({
    required this.stations,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _TableHeader(),
          const Divider(height: 1, color: AppColors.border),
          ...stations.asMap().entries.map((entry) {
            final index = entry.key;
            final station = entry.value;
            return Column(
              children: [
                _TableRow(
                  station: station,
                  onEdit: () => onEdit(station),
                  onDelete: () => onDelete(station),
                ),
                if (index < stations.length - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Tên trạm', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Tọa độ', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Liên hệ', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Sức chứa', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Trạng thái', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Thao tác', style: _headerStyle)),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final RescueStation station;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableRow({
    required this.station,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = station.status == 'active' && station.deletedAt == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              station.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${station.latitude.toStringAsFixed(5)}, '
              '${station.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              station.contactPhone ?? '—',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              station.capacity?.toString() ?? '—',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isActive
                    ? AppColors.resolvedGreenBg
                    : AppColors.activeRedBg,
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive
                      ? AppColors.resolvedGreen
                      : AppColors.brandRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Chỉnh sửa',
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Xóa',
                  color: AppColors.brandRed,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RescueStationFormDialog extends StatefulWidget {
  final RescueStation? existing;
  const _RescueStationFormDialog({this.existing});

  @override
  State<_RescueStationFormDialog> createState() =>
      _RescueStationFormDialogState();
}

class _RescueStationFormDialogState extends State<_RescueStationFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _resourcesCtrl;

  String _status = 'active';

  @override
  void initState() {
    super.initState();

    final station = widget.existing;
    final resources = _resourcesFromJson(station?.resourcesJson);

    _nameCtrl = TextEditingController(text: station?.name ?? '');
    _latCtrl = TextEditingController(
      text: station == null ? '' : station.latitude.toString(),
    );
    _lngCtrl = TextEditingController(
      text: station == null ? '' : station.longitude.toString(),
    );
    _addressCtrl = TextEditingController(text: station?.address ?? '');
    _phoneCtrl = TextEditingController(text: station?.contactPhone ?? '');
    _capacityCtrl = TextEditingController(
      text: station?.capacity?.toString() ?? '',
    );
    _resourcesCtrl = TextEditingController(text: resources.join(', '));
    _status = station?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _capacityCtrl.dispose();
    _resourcesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Chỉnh sửa trạm cứu hộ' : 'Tạo trạm cứu hộ mới'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(_nameCtrl, 'Tên trạm'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _latCtrl,
                      'Vĩ độ',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      _lngCtrl,
                      'Kinh độ',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField(_addressCtrl, 'Địa chỉ'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildTextField(_phoneCtrl, 'Số liên hệ')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      _capacityCtrl,
                      'Sức chứa',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField(
                _resourcesCtrl,
                'Tài nguyên (ngăn cách dấu phẩy)',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('active')),
                  DropdownMenuItem(value: 'full', child: Text('full')),
                  DropdownMenuItem(value: 'inactive', child: Text('inactive')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
          child: Text(isEdit ? 'Lưu thay đổi' : 'Tạo mới'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    final address = _addressCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final capacity = int.tryParse(_capacityCtrl.text.trim());

    final resources = _resourcesCtrl.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (name.isEmpty) {
      _showValidation('Tên trạm không được để trống.');
      return;
    }
    if (lat == null || lat < -90 || lat > 90) {
      _showValidation('Vĩ độ không hợp lệ (-90 đến 90).');
      return;
    }
    if (lng == null || lng < -180 || lng > 180) {
      _showValidation('Kinh độ không hợp lệ (-180 đến 180).');
      return;
    }
    if (capacity != null && capacity < 0) {
      _showValidation('Sức chứa phải lớn hơn hoặc bằng 0.');
      return;
    }

    Navigator.of(context).pop(
      _RescueStationFormData(
        name: name,
        latitude: lat,
        longitude: lng,
        address: address.isEmpty ? null : address,
        contactPhone: phone.isEmpty ? null : phone,
        capacity: capacity,
        resources: resources,
        status: _status,
      ),
    );
  }

  void _showValidation(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange.shade700),
    );
  }

  List<String> _resourcesFromJson(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      if (decoded is Map<String, dynamic>) {
        return decoded.entries
            .where((entry) => entry.value == true)
            .map((entry) => entry.key.trim())
            .where((entry) => entry.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    return rawJson
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class _RescueStationFormData {
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? contactPhone;
  final int? capacity;
  final List<String> resources;
  final String status;

  const _RescueStationFormData({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.contactPhone,
    required this.capacity,
    required this.resources,
    required this.status,
  });
}

const _headerStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);
