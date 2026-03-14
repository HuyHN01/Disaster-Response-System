const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

setGlobalOptions({ region: "asia-southeast1" });

// Hàm này sẽ tự động kích hoạt mỗi khi có 1 Document mới thêm vào collection 'posts'
exports.sendPostNotification = onDocumentCreated("posts/{postId}", async (event) => {
  const snap = event.data;
  if (!snap) return null;
  const post = snap.data();

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
      screen: "event_detail",
      eventId: post.eventId || "",
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