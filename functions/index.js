const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

setGlobalOptions({ region: "asia-southeast1" });

const USERS_COLLECTION = "users";
const BOOTSTRAP_DOC_PATH = "_system/bootstrap_auth";

const UserRoles = Object.freeze({
  SUPER_ADMIN: 0,
  ADMIN: 1,
  STAFF: 2,
  USER: 3,
});

const UserStatuses = Object.freeze({
  INACTIVE: 0,
  ACTIVE: 1,
  PENDING: 2,
  BANNED: 3,
});

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function assertRequiredString(value, fieldName) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    throw new HttpsError("invalid-argument", `${fieldName} không được để trống.`);
  }
  return normalized;
}

function assertPassword(password, confirmPassword) {
  if (String(password || "").length < 8) {
    throw new HttpsError("invalid-argument", "Mật khẩu phải có ít nhất 8 ký tự.");
  }

  if (password !== confirmPassword) {
    throw new HttpsError("invalid-argument", "Mật khẩu xác nhận không khớp.");
  }
}

function parseAllowedInt(value, allowedValues, fallback, fieldName) {
  const normalized = Number.isInteger(value) ? value : fallback;
  if (!allowedValues.includes(normalized)) {
    throw new HttpsError("invalid-argument", `${fieldName} không hợp lệ.`);
  }
  return normalized;
}

function mapToHttpsError(error, fallbackMessage) {
  if (error instanceof HttpsError) {
    return error;
  }

  const code = typeof error?.code === "string" ? error.code : "";

  switch (code) {
    case "auth/email-already-exists":
      return new HttpsError("already-exists", "Email này đã được sử dụng.");
    case "auth/invalid-email":
      return new HttpsError("invalid-argument", "Email không hợp lệ.");
    case "auth/invalid-password":
      return new HttpsError("invalid-argument", "Mật khẩu không hợp lệ.");
    case "auth/operation-not-allowed":
      return new HttpsError(
        "failed-precondition",
        "Email/Password Sign-in method chưa được bật trên Firebase Auth.",
      );
    default: {
      const rawMessage = String(error?.message || "").trim();
      return new HttpsError("internal", rawMessage || fallbackMessage);
    }
  }
}

function inferImageContentType(rawUrl, headerValue) {
  const normalizedHeader = String(headerValue || "")
    .split(";")
    .shift()
    .trim()
    .toLowerCase();

  if (normalizedHeader === "image/jpg") {
    return "image/jpeg";
  }

  const allowedFromHeader = ["image/jpeg", "image/png", "image/webp"];
  if (allowedFromHeader.includes(normalizedHeader)) {
    return normalizedHeader;
  }

  const pathname = (() => {
    try {
      return new URL(rawUrl).pathname.toLowerCase();
    } catch (_) {
      return "";
    }
  })();

  if (pathname.endsWith(".png")) return "image/png";
  if (pathname.endsWith(".webp")) return "image/webp";
  if (pathname.endsWith(".jpg") || pathname.endsWith(".jpeg")) {
    return "image/jpeg";
  }

  throw new HttpsError(
    "invalid-argument",
    "Định dạng ảnh từ URL không hỗ trợ. Vui lòng dùng JPG, JPEG, PNG hoặc WEBP.",
  );
}

async function getUserProfile(uid) {
  const snap = await db.collection(USERS_COLLECTION).doc(uid).get();
  if (!snap.exists) {
    return null;
  }

  return snap.data();
}

exports.registerInitialSuperAdmin = onCall(async (request) => {
  const data = request.data || {};

  const displayName = assertRequiredString(data.displayName, "Tên hiển thị");
  const email = normalizeEmail(assertRequiredString(data.email, "Email"));
  const password = String(data.password || "");
  const confirmPassword = String(data.confirmPassword || "");

  assertPassword(password, confirmPassword);

  const bootstrapRef = db.doc(BOOTSTRAP_DOC_PATH);
  const usersRef = db.collection(USERS_COLLECTION);

  const [bootstrapSnap, firstUserSnap] = await Promise.all([
    bootstrapRef.get(),
    usersRef.limit(1).get(),
  ]);

  const alreadyInitialized = bootstrapSnap.exists && bootstrapSnap.get("initialized") === true;
  if (alreadyInitialized || !firstUserSnap.empty) {
    if (!alreadyInitialized) {
      await bootstrapRef.set(
        {
          initialized: true,
          registrationLocked: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    throw new HttpsError(
      "failed-precondition",
      "Hệ thống đã có tài khoản quản trị đầu tiên. Đăng ký tự do đã bị khóa.",
    );
  }

  let createdUser = null;

  try {
    createdUser = await admin.auth().createUser({
      email,
      password,
      displayName,
      disabled: false,
    });

    await db.runTransaction(async (transaction) => {
      const latestBootstrap = await transaction.get(bootstrapRef);
      const initializedNow = latestBootstrap.exists && latestBootstrap.get("initialized") === true;

      if (initializedNow) {
        throw new HttpsError(
          "failed-precondition",
          "Hệ thống đã có Super Admin. Đăng ký đã bị khóa.",
        );
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      const userRef = usersRef.doc(createdUser.uid);

      transaction.set(
        userRef,
        {
          uid: createdUser.uid,
          email,
          displayName,
          photoUrl: createdUser.photoURL || null,
          role: UserRoles.SUPER_ADMIN,
          status: UserStatuses.ACTIVE,
          createdAt: now,
          updatedAt: now,
          createdBy: createdUser.uid,
          lastLoginAt: now,
          mfaEnabled: false,
        },
        { merge: true },
      );

      transaction.set(
        bootstrapRef,
        {
          initialized: true,
          registrationLocked: true,
          firstSuperAdminUid: createdUser.uid,
          updatedAt: now,
          ...(latestBootstrap.exists ? {} : { createdAt: now }),
        },
        { merge: true },
      );
    });

    return {
      uid: createdUser.uid,
      email,
      role: UserRoles.SUPER_ADMIN,
      status: UserStatuses.ACTIVE,
    };
  } catch (error) {
    if (createdUser?.uid) {
      try {
        await admin.auth().deleteUser(createdUser.uid);
      } catch (rollbackError) {
        console.error("Rollback deleteUser failed:", rollbackError);
      }
    }

    throw mapToHttpsError(error, "Không thể khởi tạo tài khoản Super Admin.");
  }
});

exports.createManagedUser = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Bạn cần đăng nhập để thực hiện thao tác này.");
  }

  const callerUid = request.auth.uid;
  const callerProfile = await getUserProfile(callerUid);

  if (!callerProfile) {
    throw new HttpsError("permission-denied", "Không tìm thấy hồ sơ tài khoản quản trị.");
  }

  const callerRole = Number(callerProfile.role);
  const callerStatus = Number(callerProfile.status);
  const callerIsActiveAdmin =
    callerStatus === UserStatuses.ACTIVE &&
    (callerRole === UserRoles.SUPER_ADMIN || callerRole === UserRoles.ADMIN);

  if (!callerIsActiveAdmin) {
    throw new HttpsError("permission-denied", "Bạn không có quyền tạo tài khoản mới.");
  }

  const data = request.data || {};
  const displayName = assertRequiredString(data.displayName, "Tên hiển thị");
  const email = normalizeEmail(assertRequiredString(data.email, "Email"));
  const password = String(data.password || "");
  const role = parseAllowedInt(
    data.role,
    [UserRoles.SUPER_ADMIN, UserRoles.ADMIN, UserRoles.STAFF, UserRoles.USER],
    UserRoles.USER,
    "Vai trò",
  );
  const status = parseAllowedInt(
    data.status,
    [UserStatuses.INACTIVE, UserStatuses.ACTIVE, UserStatuses.PENDING, UserStatuses.BANNED],
    UserStatuses.PENDING,
    "Trạng thái",
  );

  if (password.length < 8) {
    throw new HttpsError("invalid-argument", "Mật khẩu phải có ít nhất 8 ký tự.");
  }

  // Admin cấp 1 không được tạo tài khoản admin/superadmin để tránh tự nâng quyền.
  if (
    callerRole === UserRoles.ADMIN &&
    (role === UserRoles.SUPER_ADMIN || role === UserRoles.ADMIN)
  ) {
    throw new HttpsError("permission-denied", "Bạn không đủ quyền để tạo tài khoản quản trị cấp cao.");
  }

  const rawPhotoUrl = data.photoUrl || data.photoURL;
  const photoUrl = rawPhotoUrl ? String(rawPhotoUrl).trim() : null;
  const mfaEnabled = Boolean(data.mfaEnabled || false);

  let createdUser = null;

  try {
    createdUser = await admin.auth().createUser({
      email,
      password,
      displayName,
      photoURL: photoUrl,
      disabled: status !== UserStatuses.ACTIVE,
    });

    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.collection(USERS_COLLECTION).doc(createdUser.uid).set(
      {
        uid: createdUser.uid,
        email,
        displayName,
        photoUrl,
        role,
        status,
        createdAt: now,
        updatedAt: now,
        createdBy: callerUid,
        lastLoginAt: null,
        mfaEnabled,
      },
      { merge: true },
    );

    return {
      uid: createdUser.uid,
      email,
      role,
      status,
    };
  } catch (error) {
    if (createdUser?.uid) {
      try {
        await admin.auth().deleteUser(createdUser.uid);
      } catch (rollbackError) {
        console.error("Rollback deleteUser failed:", rollbackError);
      }
    }

    throw mapToHttpsError(error, "Không thể tạo tài khoản mới.");
  }
});

exports.fetchAvatarFromUrl = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Bạn cần đăng nhập để thực hiện thao tác này.");
  }

  const data = request.data || {};
  const rawUrl = assertRequiredString(data.url, "URL ảnh");

  let parsedUrl;
  try {
    parsedUrl = new URL(rawUrl);
  } catch (_) {
    throw new HttpsError("invalid-argument", "URL không hợp lệ.");
  }

  if (parsedUrl.protocol !== "http:" && parsedUrl.protocol !== "https:") {
    throw new HttpsError("invalid-argument", "URL phải bắt đầu bằng http:// hoặc https://");
  }

  const maxBytes = 5 * 1024 * 1024;
  const timeoutMs = 20000;

  const abortController = new AbortController();
  const timeoutId = setTimeout(() => abortController.abort(), timeoutMs);

  try {
    const response = await fetch(parsedUrl.toString(), {
      method: "GET",
      redirect: "follow",
      signal: abortController.signal,
      headers: {
        Accept: "image/*",
        "User-Agent": "disaster-response-avatar-fetcher/1.0",
      },
    });

    if (!response.ok) {
      throw new HttpsError(
        "invalid-argument",
        `Không thể tải ảnh từ URL (HTTP ${response.status}).`,
      );
    }

    const contentType = inferImageContentType(
      parsedUrl.toString(),
      response.headers.get("content-type"),
    );

    const contentLengthHeader = Number.parseInt(response.headers.get("content-length") || "", 10);
    if (Number.isFinite(contentLengthHeader) && contentLengthHeader > maxBytes) {
      throw new HttpsError("invalid-argument", "Kích thước ảnh vượt quá 5MB.");
    }

    const arrayBuffer = await response.arrayBuffer();
    const imageBuffer = Buffer.from(arrayBuffer);

    if (!imageBuffer.length) {
      throw new HttpsError("invalid-argument", "Dữ liệu ảnh từ URL đang rỗng.");
    }
    if (imageBuffer.length > maxBytes) {
      throw new HttpsError("invalid-argument", "Kích thước ảnh vượt quá 5MB.");
    }

    return {
      contentType,
      bytesBase64: imageBuffer.toString("base64"),
      sizeBytes: imageBuffer.length,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    if (error?.name === "AbortError") {
      throw new HttpsError("deadline-exceeded", "Hết thời gian tải ảnh từ URL. Vui lòng thử lại.");
    }

    throw new HttpsError(
      "internal",
      "Không thể tải ảnh từ URL trên máy chủ. Vui lòng thử lại.",
    );
  } finally {
    clearTimeout(timeoutId);
  }
});

// Hàm này sẽ tự động kích hoạt mỗi khi có 1 Document mới thêm vào collection 'posts'
exports.sendPostNotification = onDocumentCreated("posts/{postId}", async (event) => {
  const snap = event.data;
  if (!snap) return null;
  const post = snap.data();
  const postId = event.params.postId;

  // CHỈ gửi thông báo nếu bài đăng là Tin tức hoặc Công điện (bỏ qua SOS)
  if (post.postType !== "news" && post.postType !== "directive") {
    return null;
  }

  // Set tiêu đề theo loại
  const isDirective = post.postType === "directive";
  const title = isDirective ? "⚠️ CÔNG ĐIỆN KHẨN CẤP" : "📰 TIN TỨC MỚI";

  // Đóng gói thông điệp
  const message = {
    notification: {
      title: title,
      body: post.title || "Có thông báo mới từ Ban Chỉ huy.",
    },
    data: {
      // Mobile app đang điều hướng vào CitizenNewsDetailScreen.
      // BẮT BUỘC có postId để mở đúng bài viết.
      screen: "news_detail",
      postId: String(postId || ""),
      // Giữ eventId để tương thích ngược / analytics nếu cần.
      eventId: String(post.eventId || ""),
    },
    topic: "disaster_alerts", // Kênh mà Mobile App đang lắng nghe
  };

  try {
    // Bóp cò phát tín hiệu!
    const response = await admin.messaging().send(message);
    console.log("Đã phát thông báo thành công:", response);
    return response;
  } catch (error) {
    console.error("Lỗi khi phát thông báo:", error);
    return null;
  }
});