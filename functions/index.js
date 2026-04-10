const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const { defineSecret, defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
admin.initializeApp();

const db = admin.firestore();

setGlobalOptions({ region: "asia-southeast1" });

const USERS_COLLECTION = "users";
const BOOTSTRAP_DOC_PATH = "_system/bootstrap_auth";
const OTP_COLLECTION = "email_otp_records";

const OTP_LENGTH = 6;
const OTP_TTL_SECONDS = 120;
const OTP_COOLDOWN_SECONDS = 60;
const OTP_MAX_SENDS_PER_WINDOW = 3;
const OTP_SEND_WINDOW_SECONDS = 10 * 60;
const OTP_MAX_VERIFY_ATTEMPTS = 5;

const BREVO_API_KEY = defineSecret("BREVO_API_KEY");
const BREVO_SENDER_EMAIL = defineString("BREVO_SENDER_EMAIL");
const BREVO_SENDER_NAME = defineString("BREVO_SENDER_NAME");

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

function assertEmail(email) {
  const normalized = normalizeEmail(assertRequiredString(email, "Email"));
  const emailRegex = /^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$/;
  if (!emailRegex.test(normalized)) {
    throw new HttpsError("invalid-argument", "Địa chỉ email không hợp lệ.");
  }
  return normalized;
}

function assertOtpCode(otpCode) {
  const normalized = String(otpCode || "").trim();
  if (!/^\d{6}$/.test(normalized)) {
    throw new HttpsError("invalid-argument", "Mã OTP phải gồm đúng 6 chữ số.");
  }
  return normalized;
}

function maskEmail(email) {
  const [localPart, domain] = String(email || "").split("@");
  if (!localPart || !domain) return "***";

  if (localPart.length <= 2) {
    return `${localPart[0]}***@${domain}`;
  }

  return `${localPart.slice(0, 2)}***@${domain}`;
}

function generateOtpCode() {
  const min = 10 ** (OTP_LENGTH - 1);
  const max = (10 ** OTP_LENGTH) - 1;
  return crypto.randomInt(min, max + 1).toString();
}

function hashOtpCode(otpCode) {
  return crypto.createHash("sha256").update(otpCode).digest("hex");
}

function timingSafeHashEquals(left, right) {
  const leftBuffer = Buffer.from(String(left || ""), "utf8");
  const rightBuffer = Buffer.from(String(right || ""), "utf8");
  if (leftBuffer.length !== rightBuffer.length) return false;
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

async function getLatestOtpRecord(email) {
  const snap = await db
    .collection(OTP_COLLECTION)
    .where("email", "==", email)
    .orderBy("createdAt", "desc")
    .limit(1)
    .get();

  if (snap.empty) return null;
  return snap.docs[0];
}

function ensureBrevoConfig() {
  const senderEmail = BREVO_SENDER_EMAIL.value();
  if (!senderEmail) {
    throw new HttpsError("failed-precondition", "Thiếu cấu hình BREVO_SENDER_EMAIL.");
  }

  return {
    apiKey: BREVO_API_KEY.value(),
    senderEmail,
    senderName: BREVO_SENDER_NAME.value() || "Disaster Response",
  };
}

async function sendOtpEmailViaBrevo({ toEmail, otpCode, expiresInSeconds }) {
  const { apiKey, senderEmail, senderName } = ensureBrevoConfig();

  const htmlContent = `
    <div style="font-family: Arial, sans-serif; line-height: 1.5; color: #111827;">
      <h2 style="margin-bottom: 8px;">Xác minh đăng nhập</h2>
      <p>Mã OTP của bạn là:</p>
      <div style="font-size: 28px; font-weight: 700; letter-spacing: 4px; color: #DC2626; margin: 12px 0;">${otpCode}</div>
      <p>Mã có hiệu lực trong <strong>${Math.floor(expiresInSeconds / 60)} phút</strong>.</p>
      <p>Nếu bạn không thực hiện yêu cầu này, hãy bỏ qua email.</p>
    </div>
  `;

  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "api-key": apiKey,
    },
    body: JSON.stringify({
      sender: {
        email: senderEmail,
        name: senderName,
      },
      to: [{ email: toEmail }],
      subject: "Mã OTP đăng nhập Disaster Response",
      htmlContent,
    }),
  });

  if (!response.ok) {
    const rawBody = await response.text();
    const detail = rawBody ? ` (${rawBody.slice(0, 200)})` : "";
    throw new HttpsError(
      "unavailable",
      `Không thể gửi email OTP qua Brevo (HTTP ${response.status})${detail}`,
    );
  }
}

async function createOrGetCitizenUserByEmail(email) {
  try {
    return await admin.auth().getUserByEmail(email);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      throw error;
    }

    const local = email.split("@")[0] || "citizen";
    const displayName = local.slice(0, 40);

    const userRecord = await admin.auth().createUser({
      email,
      emailVerified: true,
      displayName,
      disabled: false,
    });

    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.collection(USERS_COLLECTION).doc(userRecord.uid).set(
      {
        uid: userRecord.uid,
        email,
        displayName,
        photoUrl: null,
        role: UserRoles.USER,
        status: UserStatuses.ACTIVE,
        createdAt: now,
        updatedAt: now,
        createdBy: "otp-email-auth",
        lastLoginAt: now,
        mfaEnabled: false,
      },
      { merge: true },
    );

    return userRecord;
  }
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

exports.sendOtp = onCall({ secrets: [BREVO_API_KEY] }, async (request) => {
  const data = request.data || {};
  const email = assertEmail(data.email);

  const latestOtpDoc = await getLatestOtpRecord(email);
  if (latestOtpDoc) {
    const latestOtp = latestOtpDoc.data();
    const createdAt = latestOtp.createdAt?.toDate?.();
    const elapsedSeconds = createdAt
      ? Math.floor((Date.now() - createdAt.getTime()) / 1000)
      : Number.POSITIVE_INFINITY;

    if (elapsedSeconds < OTP_COOLDOWN_SECONDS) {
      throw new HttpsError(
        "resource-exhausted",
        `Vui lòng đợi ${OTP_COOLDOWN_SECONDS - elapsedSeconds} giây trước khi gửi lại mã.`,
      );
    }
  }

  const windowStart = admin.firestore.Timestamp.fromMillis(
    Date.now() - (OTP_SEND_WINDOW_SECONDS * 1000),
  );

  const recentCountSnap = await db
    .collection(OTP_COLLECTION)
    .where("email", "==", email)
    .where("createdAt", ">=", windowStart)
    .count()
    .get();

  const recentAttempts = recentCountSnap.data().count || 0;
  if (recentAttempts >= OTP_MAX_SENDS_PER_WINDOW) {
    throw new HttpsError(
      "resource-exhausted",
      "Bạn đã yêu cầu mã OTP quá nhiều lần. Vui lòng thử lại sau ít phút.",
    );
  }

  const otpCode = generateOtpCode();
  const otpHash = hashOtpCode(otpCode);
  const now = Date.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(now + (OTP_TTL_SECONDS * 1000));

  const otpRef = db.collection(OTP_COLLECTION).doc();
  const otpPayload = {
    email,
    otpHash,
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    consumedAt: null,
    attemptCount: 0,
    maxAttempts: OTP_MAX_VERIFY_ATTEMPTS,
  };

  await otpRef.set(otpPayload);

  try {
    await sendOtpEmailViaBrevo({ toEmail: email, otpCode, expiresInSeconds: OTP_TTL_SECONDS });
  } catch (error) {
    await otpRef.delete();
    throw mapToHttpsError(error, "Không thể gửi OTP qua email.");
  }

  return {
    success: true,
    email: maskEmail(email),
    expiresInSec: OTP_TTL_SECONDS,
    resendAfterSec: OTP_COOLDOWN_SECONDS,
  };
});

exports.verifyOtp = onCall(async (request) => {
  const data = request.data || {};
  const email = assertEmail(data.email);
  const otpCode = assertOtpCode(data.otpCode);

  const latestOtpDoc = await getLatestOtpRecord(email);
  if (!latestOtpDoc) {
    throw new HttpsError("not-found", "Không tìm thấy mã OTP. Vui lòng yêu cầu gửi mã mới.");
  }

  const nowMs = Date.now();
  const otpInputHash = hashOtpCode(otpCode);

  await db.runTransaction(async (transaction) => {
    const freshDoc = await transaction.get(latestOtpDoc.ref);
    if (!freshDoc.exists) {
      throw new HttpsError("not-found", "Không tìm thấy mã OTP. Vui lòng yêu cầu gửi mã mới.");
    }

    const otp = freshDoc.data();

    const expiresAtMs = otp.expiresAt?.toMillis?.();
    if (!expiresAtMs || nowMs > expiresAtMs) {
      throw new HttpsError("deadline-exceeded", "Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.");
    }

    if (otp.consumedAt) {
      throw new HttpsError("failed-precondition", "Mã OTP đã được sử dụng. Vui lòng yêu cầu mã mới.");
    }

    const attempts = Number(otp.attemptCount || 0);
    const maxAttempts = Number(otp.maxAttempts || OTP_MAX_VERIFY_ATTEMPTS);
    if (attempts >= maxAttempts) {
      throw new HttpsError("resource-exhausted", "Bạn đã nhập sai OTP quá số lần cho phép.");
    }

    const matched = timingSafeHashEquals(otp.otpHash, otpInputHash);
    if (!matched) {
      transaction.update(freshDoc.ref, {
        attemptCount: attempts + 1,
      });
      throw new HttpsError("permission-denied", "Mã OTP không đúng. Vui lòng thử lại.");
    }

    transaction.update(freshDoc.ref, {
      consumedAt: admin.firestore.FieldValue.serverTimestamp(),
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  let userRecord;
  try {
    userRecord = await createOrGetCitizenUserByEmail(email);
  } catch (error) {
    throw mapToHttpsError(error, "Không thể khởi tạo tài khoản người dùng.");
  }

  await db.collection(USERS_COLLECTION).doc(userRecord.uid).set(
    {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      status: UserStatuses.ACTIVE,
      role: UserRoles.USER,
    },
    { merge: true },
  );

  const customToken = await admin.auth().createCustomToken(userRecord.uid, {
    role: UserRoles.USER,
    authProvider: "email_otp",
  });

  return {
    success: true,
    customToken,
    uid: userRecord.uid,
  };
});

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