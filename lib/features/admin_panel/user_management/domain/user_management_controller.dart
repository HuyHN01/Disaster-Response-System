import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/user_models.dart';
import 'user_management_repository.dart';

class UserManagementController extends AsyncNotifier<List<AppUser>> {
  UserManagementRepository get _repository =>
      ref.read(userManagementRepositoryProvider);

  @override
  Future<List<AppUser>> build() async {
    final initial = await _repository.fetchUsers();

    final subscription = _repository.watchUsers().listen(
      (users) {
        state = AsyncValue.data(users);
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncValue.error(error, stackTrace);
      },
    );

    ref.onDispose(subscription.cancel);

    return initial;
  }

  Future<void> refreshUsers() async {
    state = await AsyncValue.guard(_repository.fetchUsers);
  }

  Future<void> createUser({
    required String email,
    required String displayName,
    required String? photoUrl,
    required int role,
    required int status,
    required bool mfaEnabled,
  }) async {
    await _repository.createUser(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      role: role,
      status: status,
      mfaEnabled: mfaEnabled,
    );

    await refreshUsers();
  }

  Future<void> updateUser({
    required String uid,
    required String email,
    required String displayName,
    required String? photoUrl,
    required int role,
    required int status,
    required bool mfaEnabled,
  }) async {
    await _repository.updateUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      role: role,
      status: status,
      mfaEnabled: mfaEnabled,
    );

    await refreshUsers();
  }

  Future<void> softDeleteUser({required String uid}) async {
    await _repository.softDeleteUser(uid: uid);
    await refreshUsers();
  }

  Future<void> sendPasswordReset({
    required String uid,
    required String email,
  }) async {
    await _repository.sendPasswordReset(uid: uid, email: email);
  }
}

final userManagementControllerProvider =
    AsyncNotifierProvider<UserManagementController, List<AppUser>>(
      UserManagementController.new,
    );
