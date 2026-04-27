# Báo Cáo Phân Tích Kỹ Thuật: Hệ Thống Hỗ Trợ Ứng Phó Thiên Tai

## 1. Kiến Trúc Dự Án (Project Architecture)

Dự án được xây dựng dựa trên kiến trúc **Feature-Driven Architecture** (Kiến trúc hướng tính năng) kết hợp với các nguyên tắc của **Clean Architecture**. Cách tiếp cận này giúp dự án dễ dàng mở rộng, bảo trì và chia sẻ mã nguồn giữa ứng dụng User và Web Admin trong cùng một codebase.

- **Chia lô (Modularity):** Toàn bộ mã nguồn chính được đặt trong thư mục `lib/` và được chia thành hai phần cốt lõi:
  - `lib/core/`: Chứa các thành phần dùng chung cho toàn bộ dự án như cấu hình định tuyến (`routes`), cơ sở dữ liệu cục bộ (`database`), các dịch vụ bên thứ 3 (`services`), hằng số (`constants`), tiện ích (`utils`), và giao diện/theme.
  - `lib/features/`: Chứa các tính năng cụ thể của ứng dụng. Mỗi tính năng (ví dụ: `admin_panel`, `sos_alert`, `event_map`) hoạt động độc lập và bao gồm các lớp Presentation (UI), Domain/Controller (Logic), và Data (Repository/Model) của riêng nó.
- **Quản lý trạng thái (State Management):** Sử dụng **Riverpod** (`flutter_riverpod`) để quản lý trạng thái toàn cục và tiêm phụ thuộc (Dependency Injection). Riverpod giúp tách biệt rõ ràng giữa logic nghiệp vụ (Controllers) và giao diện người dùng (Widgets).
- **Lập trình hàm (Functional Programming):** Sử dụng thư viện `fpdart` để xử lý lỗi một cách an toàn và quản lý luồng dữ liệu thông qua các kiểu như `Either` hay `Option`.

---

## 2. Luồng Hoạt Động Cốt Lõi (Code Flow & Workflow)

Luồng hoạt động của hệ thống bắt đầu từ điểm vào (entry point) và phân nhánh tùy thuộc vào nền tảng và trạng thái xác thực của người dùng.

1. **Khởi tạo hệ thống (`main.dart`):**
   - Ứng dụng khởi động và gọi `WidgetsFlutterBinding.ensureInitialized()`.
   - Các dịch vụ cốt lõi (Core Services) được khởi tạo: Firebase (Core, Auth, Firestore), Supabase (đọc thông tin từ file `.env`), và Cơ sở dữ liệu cục bộ (Drift).
   - `FCMService` được khởi tạo để xử lý thông báo đẩy (Push Notifications) chạy ngầm nhằm không chặn quá trình render màn hình đầu tiên.
2. **Cấu hình định tuyến (`AppRouter`):**
   - Sử dụng **GoRouter** để quản lý điều hướng. Dựa trên trạng thái đăng nhập và vai trò (Admin hoặc User), GoRouter sẽ quyết định màn hình đích. Nếu là người dùng thông thường trên mobile, luồng sẽ rẽ nhánh vào `lib/features/user_mobile`. Nếu là Admin trên Web, luồng sẽ rẽ vào `lib/features/admin_panel`.
3. **Đồng bộ dữ liệu thời gian thực (`OmniDisasterApp`):**
   - Lớp `OmniDisasterApp` lắng nghe các luồng dữ liệu (Streams) từ Firebase thông qua `syncService` (như thông tin người dùng, sự kiện thiên tai, trạm cứu hộ). Khi có dữ liệu mới, Riverpod sẽ kích hoạt làm mới giao diện (`ref.invalidate()`) để hiển thị thông tin cập nhật tức thời.
4. **Luồng xử lý tính năng (Feature Flow):**
   - **Tương tác UI:** Người dùng thao tác trên các Widget (ví dụ: nhấn nút gửi SOS).
   - **Giao tiếp Logic:** Widget gọi phương thức từ các Riverpod Notifiers/Controllers.
   - **Xử lý Dữ liệu:** Controller tương tác với các file trong `lib/core/services` hoặc các Data Repositories để gọi API (Firebase/Supabase), sau đó cập nhật State. Riverpod sẽ tự động cập nhật lại UI dựa trên State mới.

---

## 3. Các Chức Năng Chính (Key Features)

Dự án bao gồm các module chức năng chính sau (tương ứng với các thư mục trong `lib/features`):

- **User Mobile (`user_mobile`):** Giao diện chính dành cho người dân sử dụng trên điện thoại, là trung tâm điều hướng đến các tính năng khác dành cho công dân.
- **Admin Panel (`admin_panel`):** Giao diện quản trị viên (thường trên Web), cung cấp bảng điều khiển để quản lý các sự kiện thiên tai, tin tức, theo dõi và xử lý các tín hiệu cầu cứu (SOS), và quản lý các trạm cứu hộ.
- **Xác thực (`auth`):** Hệ thống đăng nhập, đăng ký và phân quyền người dùng (Citizen/Admin).
- **Cảnh báo SOS (`sos_alert`):** Tính năng cốt lõi cho phép người dùng gửi tín hiệu cấp cứu khẩn cấp kèm theo vị trí địa lý tức thời.
- **Bản đồ sự kiện (`event_map`):** Bản đồ tương tác hiển thị trực quan các khu vực đang có thiên tai, vị trí các trạm cứu hộ an toàn và các điểm cảnh báo sự cố.
- **Tin tức cho công dân (`citizen_news`):** Khu vực cập nhật tin tức, thông báo khẩn cấp và các hướng dẫn an toàn từ ban quản trị đến người dân.
- **Trợ lý ảo AI (`ai_assistant`):** Tích hợp trí tuệ nhân tạo để hỏi đáp, tư vấn kỹ năng sinh tồn và hướng dẫn phản ứng nhanh trong các tình huống khẩn cấp.

---

## 4. Công Cụ và Dịch Vụ Đã Sử Dụng (Tools & Technologies)

Hệ thống sử dụng một hệ sinh thái các công cụ hiện đại và mạnh mẽ:

### Frontend & Framework
- **Flutter & Dart (SDK ^3.10.8):** Framework cốt lõi để phát triển đa nền tảng (Mobile & Web) từ một mã nguồn.
- **GoRouter:** Thư viện định tuyến chuẩn mực, quản lý deep-linking và điều hướng phức tạp.
- **Riverpod (`flutter_riverpod`):** Giải pháp State Management an toàn và dễ kiểm thử.

### Backend & Cloud Services
- **Firebase Ecosystem:** 
  - *Firebase Core & Auth:* Quản lý vòng đời ứng dụng và xác thực người dùng (hỗ trợ thêm `google_sign_in`).
  - *Cloud Firestore:* Cơ sở dữ liệu NoSQL thời gian thực.
  - *Cloud Functions:* Chạy mã logic backend tùy chỉnh.
  - *Firebase Storage:* Lưu trữ hình ảnh và tệp phương tiện.
  - *Firebase Messaging (FCM) & Local Notifications:* Gửi và nhận thông báo đẩy.
- **Supabase (`supabase_flutter`):** Được sử dụng như một dịch vụ backend bổ trợ (có thể dùng cho cơ sở dữ liệu quan hệ hoặc các chức năng đặc thù khác).

### Local Database & Storage
- **Drift (`drift`, `sqlite3_flutter_libs`):** Thư viện ORM mạnh mẽ được xây dựng trên nền SQLite, dùng để lưu trữ dữ liệu ngoại tuyến (offline-first).
- **Path Provider & Shared Preferences (nếu có):** Quản lý lưu trữ file tạm thời và cài đặt cục bộ.

### Bản Đồ & Định Vị (Mapping & Geolocation)
- **Flutter Map (`flutter_map`) & LatLong2:** Hiển thị bản đồ dựa trên OpenStreetMap hoặc các tile server tùy chỉnh (thay thế cho Google Maps để tiết kiệm chi phí/tăng tính tùy biến).
- **Geolocator:** Lấy tọa độ GPS và theo dõi vị trí người dùng.
- **Flutter Polyline Points:** Vẽ tuyến đường trên bản đồ (VD: chỉ đường đến trạm cứu hộ).

### Tích Hợp AI
- **Google Generative AI (`google_generative_ai`):** Tích hợp mô hình Gemini AI để cung cấp sức mạnh cho tính năng Trợ lý ảo (AI Assistant).

### Tiện Ích Khác
- **Soạn thảo văn bản:** `flutter_quill` (Rich Text Editor) cho phép Admin soạn thảo tin tức với định dạng phức tạp.
- **Xử lý file & hình ảnh:** `file_picker`, `image_picker`, `crop_your_image` phục vụ cho việc tải lên và chỉnh sửa ảnh/file.
- **Kết nối mạng:** `http` và `connectivity_plus` (kiểm tra trạng thái mạng).
- **Bảo mật:** `flutter_dotenv` để quản lý biến môi trường an toàn (API Keys).
