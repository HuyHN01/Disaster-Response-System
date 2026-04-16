// lib/features/user_mobile/presentation/mobile_profile_screen.dart

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:disaster_response_app/core/services/firebase/firebase_avatar_storage_service.dart';
import 'package:disaster_response_app/features/auth/domain/email_otp_auth_repository.dart';

// =============================================================================
// THEME TOKENS
// =============================================================================
class _PC {
  static const Color scaffold      = Color(0xFFF5F7FA);
  static const Color cardBg        = Color(0xFFFFFFFF);
  static const Color primary       = Color(0xFFDC2626);
  static const Color primaryDark   = Color(0xFFB91C1C);
  static const Color primaryLight  = Color(0xFFFEF2F2);
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted     = Color(0xFF9CA3AF);
  static const Color border        = Color(0xFFE5E7EB);
  static const Color inputBg       = Color(0xFFF9FAFB);
  static const Color green         = Color(0xFF16A34A);
  static const Color greenLight    = Color(0xFFDCFCE7);
  static const Color amber         = Color(0xFFD97706);
  static const Color amberLight    = Color(0xFFFFFBEB);
  static const Color blue          = Color(0xFF2563EB);
  static const Color blueLight     = Color(0xFFEFF6FF);
}

// =============================================================================
// DATA MODEL  (map from your Firestore document)
// =============================================================================
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final int role;         // 0=superadmin 1=admin 2=staff 3=user
  final int status;       // 0=inactive 1=active 2=pending 3=banned
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool mfaEnabled;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.lastLoginAt,
    required this.mfaEnabled,
  });
}

// =============================================================================
// MOBILE PROFILE SCREEN
// =============================================================================
class MobileProfileScreen extends ConsumerStatefulWidget {
  /// Pass the current logged-in user profile.
  final UserProfile user;

  const MobileProfileScreen({super.key, required this.user});

  @override
  ConsumerState<MobileProfileScreen> createState() =>
      _MobileProfileScreenState();
}

class _MobileProfileScreenState extends ConsumerState<MobileProfileScreen> {
  static const int _maxAvatarBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  final FocusNode _nameFocus = FocusNode();

  bool _isEditingName = false;
  bool _isSavingName  = false;
  bool _isUploadingAvatar = false;
  String? _displayNameOverride;
  String? _photoUrlOverride;
  Uint8List? _avatarPreviewBytes;

  String get _currentName => _nameController.text.trim();
  String get _resolvedDisplayName =>
      (_displayNameOverride ?? widget.user.displayName).trim();
  String? get _resolvedPhotoUrl {
    final overrideUrl = (_photoUrlOverride ?? '').trim();
    if (overrideUrl.isNotEmpty) return overrideUrl;
    final fromUser = (widget.user.photoUrl ?? '').trim();
    return fromUser.isNotEmpty ? fromUser : null;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _resolvedDisplayName);
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && _isEditingName) {
        _cancelEditName();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MobileProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.displayName != widget.user.displayName &&
        _displayNameOverride != null &&
        _displayNameOverride == widget.user.displayName) {
      _displayNameOverride = null;
    }

    if (!_isEditingName && _nameController.text != _resolvedDisplayName) {
      _nameController.text = _resolvedDisplayName;
    }

    if (_photoUrlOverride != null && widget.user.photoUrl == _photoUrlOverride) {
      _photoUrlOverride = null;
      _avatarPreviewBytes = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> _onSaveName() async {
    if (_currentName.isEmpty || _currentName == _resolvedDisplayName) {
      _cancelEditName();
      return;
    }
    _nameFocus.unfocus();
    setState(() => _isSavingName = true);

    final newName = _currentName;
    final previousName = _resolvedDisplayName;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'no-current-user');
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        await user.updateDisplayName(newName);
        await user.reload();
      } catch (_) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': previousName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        rethrow;
      }

      if (!mounted) return;
      setState(() {
        _displayNameOverride = newName;
        _isEditingName = false;
      });
      _nameController.text = newName;
      _nameController.selection = TextSelection.collapsed(
        offset: _nameController.text.length,
      );
      _showSnackbar('Tên hiển thị đã được cập nhật', isSuccess: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackbar('Không thể cập nhật tên hiển thị. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  void _cancelEditName() {
    _nameFocus.unfocus();
    setState(() {
      _isEditingName = false;
      _nameController.text = _resolvedDisplayName;
    });
  }

  Future<void> _onChangeAvatar() async {
    // Show bottom sheet picker
    _showAvatarOptions();
  }

  Future<void> _pickFromGallery() async {
    await _pickAndCropAvatar(ImageSource.gallery);
  }

  Future<void> _pickFromCamera() async {
    await _pickAndCropAvatar(ImageSource.camera);
  }

  Future<void> _pickAndCropAvatar(ImageSource source) async {
    if (_isUploadingAvatar) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    try {
      final selectedFile = await _imagePicker.pickImage(source: source);
      if (!mounted || selectedFile == null) return;

      final extension = _extractExtension(selectedFile.name);
      if (!_allowedExtensions.contains(extension)) {
        _showSnackbar(
          'Định dạng ảnh không hỗ trợ. Vui lòng chọn JPG, JPEG, PNG hoặc WEBP.',
        );
        return;
      }

      final bytes = await selectedFile.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maxAvatarBytes) {
        _showSnackbar('Kích thước ảnh vượt quá 5MB.');
        return;
      }

      final croppedImage = await showDialog<Uint8List>(
        context: context,
        barrierDismissible: !_isUploadingAvatar,
        builder: (_) => _AvatarCropDialog(imageBytes: bytes),
      );

      if (!mounted || croppedImage == null) return;

      setState(() {
        _isUploadingAvatar = true;
        _avatarPreviewBytes = croppedImage;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const EmailOtpAuthException(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }

      String uploadedUrl;
      try {
        uploadedUrl = await FirebaseAvatarStorageService.uploadAdminAvatar(
          uid: user.uid,
          imageBytes: croppedImage,
          contentType: _contentTypeFromExtension(extension),
        );
      } on FirebaseException catch (e) {
        throw EmailOtpAuthException(_mapStorageError(e));
      } catch (_) {
        throw const EmailOtpAuthException(
          'Không thể tải ảnh lên Storage. Vui lòng thử lại.',
        );
      }

      try {
        await ref
            .read(emailOtpAuthRepositoryProvider)
            .updateCurrentUserAvatar(photoUrl: uploadedUrl);
      } on EmailOtpAuthException catch (e) {
        final fallbackOk = await _syncAvatarProfileFallback(uploadedUrl);
        if (!fallbackOk) rethrow;
      } catch (_) {
        final fallbackOk = await _syncAvatarProfileFallback(uploadedUrl);
        if (!fallbackOk) {
          throw const EmailOtpAuthException(
            'Ảnh đã tải lên nhưng đồng bộ hồ sơ thất bại. Vui lòng thử lại.',
          );
        }
      }

      if (!mounted) return;
      setState(() => _photoUrlOverride = uploadedUrl);
      _showSnackbar('Ảnh đại diện đã được cập nhật', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      final message = _mapAvatarError(e);
      setState(() {
        _photoUrlOverride = null;
        _avatarPreviewBytes = null;
      });
      _showSnackbar(message);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  String _extractExtension(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == normalized.length - 1) {
      return '';
    }
    return normalized.substring(dotIndex + 1);
  }

  String _contentTypeFromExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<bool> _syncAvatarProfileFallback(String photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final normalizedUrl = photoUrl.trim();
    if (normalizedUrl.isEmpty) return false;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    try {
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        await docRef.set({
          'photoUrl': normalizedUrl,
          'updatedAt': now,
        }, SetOptions(merge: true));
      } else {
        await docRef.set({
          'uid': user.uid,
          'email': (user.email ?? '').trim().toLowerCase(),
          'displayName': (user.displayName ?? '').trim(),
          'photoUrl': normalizedUrl,
          'role': 3,
          'status': 1,
          'createdAt': now,
          'updatedAt': now,
          'createdBy': null,
          'lastLoginAt': now,
          'mfaEnabled': false,
        }, SetOptions(merge: true));
      }

      try {
        await user.updatePhotoURL(normalizedUrl);
        await user.reload();
      } catch (_) {
        // Firestore profile is primary source for mobile profile UI.
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  String _mapAvatarError(Object error) {
    if (error is EmailOtpAuthException) {
      return error.message;
    }

    if (error is ArgumentError) {
      final message = error.message?.toString().trim() ?? '';
      if (message.isNotEmpty) return message;
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Không có quyền truy cập ảnh đại diện. Vui lòng liên hệ quản trị viên.';
        case 'unauthenticated':
          return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        case 'network-request-failed':
        case 'unavailable':
          return 'Mạng không ổn định. Vui lòng thử lại.';
        default:
          final message = error.message?.trim() ?? '';
          if (message.isNotEmpty) return message;
      }
    }

    return 'Không thể cập nhật ảnh đại diện. Vui lòng thử lại.';
  }

  String _mapStorageError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Không có quyền tải ảnh lên Storage. Vui lòng liên hệ quản trị viên.';
      case 'unauthenticated':
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 'network-request-failed':
      case 'unavailable':
        return 'Không thể kết nối đến Storage. Vui lòng kiểm tra mạng.';
      case 'canceled':
        return 'Tải ảnh lên Storage đã bị huỷ.';
      case 'unknown':
        return 'Storage gặp lỗi không xác định. Vui lòng thử lại sau vài giây.';
      default:
        final message = error.message?.trim() ?? '';
        if (message.isNotEmpty) return message;
        return 'Không thể tải ảnh lên Storage. Vui lòng thử lại.';
    }
  }

  Future<void> _onSignOut() async {
    final confirmed = await _showConfirmDialog(
      title: 'Đăng xuất',
      message: 'Bạn có chắc muốn đăng xuất khỏi tài khoản này không?',
      confirmLabel: 'Đăng xuất',
      isDanger: true,
    );
    if (!confirmed) return;

    try {
      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;
      _showSnackbar('Không thể đăng xuất. Vui lòng thử lại.');
    }
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------
  void _showSnackbar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? _PC.green : _PC.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDanger = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(
                color: _PC.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Huỷ',
                  style: TextStyle(color: _PC.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  confirmLabel,
                  style: TextStyle(
                    color: isDanger ? _PC.primary : _PC.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvatarOptionSheet(
        onGallery: _pickFromGallery,
        onCamera: _pickFromCamera,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PC.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ───────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader()),

            // ── Avatar + Name section ─────────────────────────────────────
            SliverToBoxAdapter(child: _buildAvatarCard()),

            // ── Account info section ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionTitle(title: 'Thông tin tài khoản'),
            ),
            SliverToBoxAdapter(child: _buildInfoCard()),

            // ── Security section ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionTitle(title: 'Bảo mật & Quyền riêng tư'),
            ),
            SliverToBoxAdapter(child: _buildSecurityCard()),

            // ── Sign out ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _SignOutButton(onPressed: _onSignOut),
              ),
            ),

            // ── Bottom padding ────────────────────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        color: _PC.cardBg,
        border: Border(bottom: BorderSide(color: _PC.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hồ sơ cá nhân',
                  style: TextStyle(
                    color: _PC.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Quản lý thông tin tài khoản của bạn',
                  style: TextStyle(
                    color: _PC.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Role badge
          _RoleBadge(role: widget.user.role),
        ],
      ),
    );
  }

  Widget _buildAvatarCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _PC.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Avatar ────────────────────────────────────────────────────────
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Avatar circle
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _PC.border, width: 2),
                ),
                child: ClipOval(
                  child: _avatarPreviewBytes != null
                      ? Image.memory(
                          _avatarPreviewBytes!,
                          fit: BoxFit.cover,
                        )
                      : _resolvedPhotoUrl != null
                      ? Image.network(
                          _resolvedPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _AvatarFallback(name: _resolvedDisplayName),
                        )
                      : _AvatarFallback(name: _resolvedDisplayName),
                ),
              ),
              if (_isUploadingAvatar)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.22),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              // Edit avatar button
              GestureDetector(
                onTap: _isUploadingAvatar ? null : _onChangeAvatar,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _PC.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _PC.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Display name (editable) ────────────────────────────────────
          _isEditingName
              ? _NameEditField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  isSaving: _isSavingName,
                  onSave: _onSaveName,
                  onCancel: _cancelEditName,
                )
              : _NameDisplayRow(
                  name: _resolvedDisplayName,
                  onEdit: () {
                    setState(() => _isEditingName = true);
                    Future.delayed(
                      const Duration(milliseconds: 80),
                      () => _nameFocus.requestFocus(),
                    );
                  },
                ),

          const SizedBox(height: 6),

          // ── Status chip ───────────────────────────────────────────────
          _StatusChip(status: widget.user.status),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final dateFormat = DateFormat('dd/MM/yyyy • HH:mm');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: _PC.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.email_outlined,
            iconColor: _PC.blue,
            iconBg: _PC.blueLight,
            label: 'Email',
            value: widget.user.email,
            isReadOnly: true,
            isFirst: true,
          ),
          _Divider(),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            iconColor: _PC.textSecondary,
            iconBg: const Color(0xFFF3F4F6),
            label: 'Ngày tạo tài khoản',
            value: dateFormat.format(widget.user.createdAt),
          ),
          _Divider(),
          _InfoRow(
            icon: Icons.access_time_rounded,
            iconColor: _PC.textSecondary,
            iconBg: const Color(0xFFF3F4F6),
            label: 'Đăng nhập gần nhất',
            value: dateFormat.format(widget.user.lastLoginAt),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: _PC.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _MfaRow(
        enabled: widget.user.mfaEnabled,
        onToggle: () {
          // TODO: navigate to MFA setup flow or toggle MFA
        },
      ),
    );
  }
}

// =============================================================================
// NAME DISPLAY ROW
// =============================================================================
class _NameDisplayRow extends StatelessWidget {
  final String name;
  final VoidCallback onEdit;

  const _NameDisplayRow({required this.name, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: _PC.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _PC.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.edit_rounded,
              size: 14,
              color: _PC.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// NAME EDIT FIELD
// =============================================================================
class _NameEditField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _NameEditField({
    required this.controller,
    required this.focusNode,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            maxLength: 50,
            style: const TextStyle(
              color: _PC.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: _PC.inputBg,
              counterText: '',
              hintText: 'Nhập tên hiển thị',
              hintStyle: const TextStyle(color: _PC.textMuted, fontSize: 15),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _PC.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _PC.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _PC.primary, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: isSaving ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                side: const BorderSide(color: _PC.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text(
                'Huỷ',
                style: TextStyle(
                  color: _PC.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_PC.primary, _PC.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: ElevatedButton(
                  onPressed: isSaving ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Lưu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// AVATAR FALLBACK  (initials)
// =============================================================================
class _AvatarFallback extends StatelessWidget {
  final String name;

  const _AvatarFallback({required this.name});

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _PC.primaryLight,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: const TextStyle(
          color: _PC.primary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// ROLE BADGE
// =============================================================================
class _RoleBadge extends StatelessWidget {
  final int role;

  const _RoleBadge({required this.role});

  _BadgeData get _data => switch (role) {
        0 => _BadgeData('Super Admin', const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
        1 => _BadgeData('Admin', _PC.primary, _PC.primaryLight),
        2 => _BadgeData('Nhân viên', _PC.amber, _PC.amberLight),
        _ => _BadgeData('Người dùng', _PC.blue, _PC.blueLight),
      };

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: d.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: d.color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            d.label,
            style: TextStyle(
              color: d.color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeData {
  final String label;
  final Color color;
  final Color bg;
  const _BadgeData(this.label, this.color, this.bg);
}

// =============================================================================
// STATUS CHIP
// =============================================================================
class _StatusChip extends StatelessWidget {
  final int status;

  const _StatusChip({required this.status});

  _BadgeData get _data => switch (status) {
        1 => _BadgeData('Tài khoản đang hoạt động', _PC.green, _PC.greenLight),
        2 => _BadgeData('Đang chờ xác nhận', _PC.amber, _PC.amberLight),
        3 => _BadgeData('Tài khoản bị khoá', _PC.primary, _PC.primaryLight),
        _ => _BadgeData('Không hoạt động', _PC.textMuted, const Color(0xFFF3F4F6)),
      };

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: d.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == 1
                ? Icons.check_circle_rounded
                : status == 3
                    ? Icons.block_rounded
                    : Icons.hourglass_top_rounded,
            size: 12,
            color: d.color,
          ),
          const SizedBox(width: 5),
          Text(
            d.data,
            style: TextStyle(
              color: d.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

extension on _BadgeData {
  // alias "label" as "data" for StatusChip clarity
  String get data => label;
}

// =============================================================================
// INFO ROW
// =============================================================================
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final bool isReadOnly;
  final bool isFirst;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.isReadOnly = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(18) : Radius.zero,
          bottom: isLast ? const Radius.circular(18) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),

          // Label + Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _PC.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _PC.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Read-only lock badge
          if (isReadOnly)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _PC.inputBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _PC.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 10, color: _PC.textMuted),
                  SizedBox(width: 3),
                  Text(
                    'Cố định',
                    style: TextStyle(
                      color: _PC.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// MFA ROW
// =============================================================================
class _MfaRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback onToggle;

  const _MfaRow({required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: enabled ? _PC.greenLight : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: enabled ? _PC.green : _PC.textMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xác thực hai lớp (MFA)',
                  style: TextStyle(
                    color: _PC.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled ? 'Đã bật — tài khoản được bảo vệ' : 'Chưa bật — khuyến nghị bật',
                  style: TextStyle(
                    color: enabled ? _PC.green : _PC.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Toggle chip
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: enabled ? _PC.greenLight : _PC.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: enabled
                      ? _PC.green.withOpacity(0.3)
                      : _PC.primary.withOpacity(0.3),
                ),
              ),
              child: Text(
                enabled ? 'Quản lý' : 'Bật ngay',
                style: TextStyle(
                  color: enabled ? _PC.green : _PC.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SIGN OUT BUTTON
// =============================================================================
class _SignOutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SignOutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(
          Icons.logout_rounded,
          size: 18,
          color: _PC.primary,
        ),
        label: const Text(
          'Đăng xuất',
          style: TextStyle(
            color: _PC.primary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _PC.primary.withOpacity(0.4), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// AVATAR OPTION SHEET
// =============================================================================
class _AvatarOptionSheet extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  const _AvatarOptionSheet({
    required this.onGallery,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: _PC.cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _PC.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Thay đổi ảnh đại diện',
            style: TextStyle(
              color: _PC.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 16),

          _SheetOption(
            icon: Icons.photo_library_rounded,
            iconColor: _PC.blue,
            iconBg: _PC.blueLight,
            label: 'Chọn từ thư viện',
            onTap: onGallery,
            isFirst: true,
          ),
          _SheetDivider(),
          _SheetOption(
            icon: Icons.camera_alt_rounded,
            iconColor: _PC.primary,
            iconBg: _PC.primaryLight,
            label: 'Chụp ảnh mới',
            onTap: onCamera,
            isLast: true,
          ),

          const SizedBox(height: 12),

          // Cancel
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _PC.inputBg,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Huỷ',
                style: TextStyle(
                  color: _PC.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _SheetOption({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(14) : Radius.zero,
        bottom: isLast ? const Radius.circular(14) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: _PC.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: _PC.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 68,
      endIndent: 0,
      color: _PC.border,
    );
  }
}

// =============================================================================
// SHARED HELPERS
// =============================================================================
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: _PC.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 68,
      endIndent: 0,
      color: _PC.border,
    );
  }
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final CropController _cropController = CropController();
  bool _isCropping = false;
  String? _errorMessage;

  void _onCropConfirm() {
    if (_isCropping) return;
    setState(() {
      _isCropping = true;
      _errorMessage = null;
    });
    _cropController.cropCircle();
  }

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        if (!mounted) return;
        Navigator.of(context).pop(croppedImage);
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() {
          _isCropping = false;
          _errorMessage = 'Không thể cắt ảnh: $cause';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: _PC.cardBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cắt ảnh đại diện',
                style: TextStyle(
                  color: _PC.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _PC.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _PC.border),
                ),
                clipBehavior: Clip.hardEdge,
                child: Crop(
                  image: widget.imageBytes,
                  controller: _cropController,
                  withCircleUi: true,
                  interactive: true,
                  fixCropRect: true,
                  baseColor: _PC.inputBg,
                  maskColor: Colors.black.withValues(alpha: 0.45),
                  progressIndicator: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  onCropped: _onCropped,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Kéo để di chuyển ảnh. Chụm để phóng to hoặc thu nhỏ.',
                style: TextStyle(
                  color: _PC.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: _PC.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isCropping
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Huỷ',
                      style: TextStyle(color: _PC.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isCropping ? null : _onCropConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _PC.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isCropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Xác nhận',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}