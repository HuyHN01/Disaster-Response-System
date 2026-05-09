# Prompt 1:

Chào bạn, trong chặng phát triển này, bạn sẽ đảm nhận vai trò là Kỹ sư phụ trách "Quản lý Dữ liệu Sự kiện & Thống kê Thiệt hại". Hãy quét và phân tích toàn bộ kiến trúc dự án hiện tại, sau đó lập một Kế hoạch triển khai chi tiết để hoàn thành các mục tiêu nghiệp vụ sau:

MỤC TIÊU 1: Xây dựng module Thống kê thiệt hại
Hãy tìm các khu vực liên quan đến Quản lý Sự kiện thiên tai dành cho Admin. Bổ sung thêm các trường nhập liệu để thu thập và quản lý các số liệu sau: Số người chết, Số người mất tích, Số người bị thương, Số nhà bị hư hại/tốc mái, và Tổng tài sản thiệt hại ước tính.

MỤC TIÊU 2: Cơ chế lưu trữ Lịch sử (Snapshot)
Đây là yêu cầu cốt lõi về mặt dữ liệu: Tuyệt đối không được ghi đè làm mất dữ liệu cũ khi Admin cập nhật các con số thống kê ở Mục tiêu 1. Hãy thiết kế cơ sở dữ liệu và luồng xử lý sao cho hệ thống lưu lại được các "dấu mốc" thời gian (Ví dụ: 8h sáng báo 2 người mất tích, 15h chiều cập nhật thành 4 người -> Hệ thống phải lưu cả 2 bản ghi này). Đồng thời, hãy cấu trúc lại logic truy vấn để các giao diện bên ngoài luôn luôn tự động lấy bản ghi mới nhất để hiển thị.

MỤC TIÊU 3: Thiết lập quyền quản lý Trạm cứu trợ
Hãy tìm hiểu cách hệ thống đang quản lý thực thể Trạm cứu trợ và thiết lập một ràng buộc logic cứng: Khi Admin tạo một "Trạm cứu trợ" mới, bắt buộc trạm đó phải được gắn với một "Sự kiện thiên tai". Đảm bảo mỗi trạm sinh ra chỉ phục vụ cho đúng một sự kiện.

YÊU CẦU ĐẦU RA:
Xin đừng vội sinh ra mã nguồn. Bằng khả năng phân tích kiến trúc (Database, State Management, UI) mà dự án đang sử dụng, hãy trình bày cho tôi một Kế hoạch triển khai (Step-by-step Plan) rõ ràng. Hãy cho tôi biết bạn định thiết kế cấu trúc lưu trữ lịch sử như thế nào và thứ tự các bước bạn sẽ thực hiện để tôi có thể xét duyệt trước khi bắt đầu viết code.

# Github Copilot Answer 1:
Find disaster event and rescue station models and UI

Searched codebase for "Disaster Event model Sự kiện thiên tai", 19 results

Searched codebase for "Rescue Station model Trạm cứu trợ", 19 results

Searched codebase for "admin UI dialog form for disaster event rescue station", 9 results

Searched codebase for "state management Riverpod Provider StateNotifier", 28 results

Created memory file [](file:///c%3A/Users/hh092/AppData/Roaming/Code/User/workspaceStorage/22fe699dc174314c2ee47e4c9b8ca49d/GitHub.copilot-chat/memory-tool/memories/YTAyZjJhOWMtOTYxMS00YzI3LWI3N2ItYzViOWZjMTQyZWJm/plan.md)

Cảm ơn bạn đã cung cấp yêu cầu. Sau khi khảo sát kiến trúc dự án (sử dụng **Drift** cho Local Database Storage, **Firebase** cho đồng bộ, và **Riverpod** cho State Management), tôi xin đề xuất Kế hoạch triển khai chi tiết đáp ứng 3 mục tiêu bạn đã nêu.

Như yêu cầu, logic lưu trữ lịch sử được chọn sẽ là cơ chế **Insert-Only (Snapshot) Table** thay vì ghi đè trực tiếp lên schema của bảng `DisasterEvent`.

Dưới đây là Kế hoạch Triển khai (đã được lưu vào bộ nhớ dự án) để bạn phê duyệt trước khi chúng ta tiến hành code:

## Plan: Quản Quản lý Dữ liệu Sự kiện & Thống kê

Xây dựng module thống kê thiệt hại lưu trữ theo lịch sử (snapshot) và liên kết Trạm cứu trợ với Sự kiện thiên tai cụ thể, duy trì kiến trúc offline-first của hệ thống qua Drift và Riverpod.

**Steps**

**Phase 1: Database & Sync (Core)**
1. Mở rộng cơ sở dữ liệu: Khai báo bảng mới `EventDamageStats` dạng snapshot (gồm `id`, `eventId`, các field thống kê, `reportedAt`, `reportedBy`) trong app_database.dart.
2. Thiết lập ràng buộc Trạm cứu trợ: Bổ sung TextColumn `eventId` làm khóa tham chiếu bắt buộc cho entity `RescueStations` trong app_database.dart.
3. Chạy lệnh generator (`build_runner`) để Flutter sinh lại code schema tại `app_database.g.dart`.
4. Cập nhật rule đồng bộ Firestore trong sync_service.dart cho bảng mới và trường mới.

**Phase 2: Logic & State Management**
5. Triển khai truy vấn: Tạo `EventDamageStatsRepository` chứa hàm `insertStat()` và `watchLatestStat(eventId)` (sử dụng query `orderBy descending` ngày báo cáo và `limit 1`).
6. Cung cấp State: Định nghĩa các provider tương ứng (VD: `latestEventStatsProvider`) để UI stream trực tiếp từ local DB.
7. Ràng buộc Logic Trạm cứu trợ: Cập nhật hàm `createStation` trong rescue_station_controller.dart yêu cầu truyền bắt buộc tham số `eventId`.

**Phase 3: Admin UI**
8. Gắn Trạm vào Sự kiện: Chỉnh sửa Form tạo mới trạm trong admin_rescue_stations_screen.dart thêm Dropdown chọn Sự kiện đang Active.
9. Cập nhật Thống kê: Xây dựng Dialog "Cập nhật Thống kê Thiệt hại" (chỉ Input form, khi submit controller sẽ gọi Insert, không gọi Update).
10. Hiển thị Snapshot: Bổ sung widget trong admin_event_detail_screen.dart consume stream data từ provider trên để tự động render bảng tổng kết mới nhất.

**Relevant files**
- app_database.dart — Thêm table `EventDamageStats`, thêm field `eventId` cho `RescueStations`.
- rescue_station_controller.dart — Logic giới hạn khi tạo Trạm.
- admin_event_detail_screen.dart — Hiển thị thiệt hại thống kê tự động.

**Verification**
1. Test lưu lịch sử: Admin nhập cập nhật thiệt hại 3 lần. Truy vấn trực tiếp Drift SQLite DB xác nhận có 3 Row dữ liệu độc lập với các timestamp khác nhau thay vì 1 Row bị ghi đè.
2. Test giao diện: Giao diện màn hình Chi tiết sự kiện lập tức hiển thị con số của lần nhắc thứ 3 nhờ cơ chế Stream Provider.
3. Test tạo trạm: Bấm "Tạo trạm" khi chưa chọn `eventId` -> Bị vướng Validation báo lỗi.

**Decisions**
- Thiết kế Data theo mô hình Event-Sourced/Snapshot: Tách biệt bảng Sự Kiện và Bảng Thống kê, giúp bảo toàn toàn bộ dòng thời gian của các biến động.
- Dữ liệu `eventId` trong `RescueStation` chỉ xử lý logic từ phía code ứng dụng, bỏ qua Foreign Key constraints dưới CSDL SQL để giảm dependency crash nếu đồng bộ Firebase lỗi một chiều.

Bạn đánh giá các bước tiếp cận trên đã đúng với ý đồ kinh doanh của hệ thống chưa? Nếu ổn, tôi có thể sẵn sàng bàn giao bản thiết kế này để tiến hành khai thác mã nguồn.

# Prompt 2:
Kế hoạch của bạn rất xuất sắc, đặc biệt là quyết định dùng bảng Snapshot để lưu lịch sử. Tôi duyệt hướng tiếp cận này.

Tuy nhiên, tôi muốn điều chỉnh lại phạm vi công việc (Scope) của nhiệm vụ này như sau:

1. HỦY BỎ TẠM THỜI nhiệm vụ liên quan đến Trạm cứu trợ: > Tạm thời bỏ qua hoàn toàn việc gán eventId cho Trạm cứu trợ. Chúng ta sẽ không đụng đến bảng RescueStations hay các UI liên quan đến nó trong lúc này. Chỉ tập trung 100% vào Thống kê thiệt hại.

2. THÊM YÊU CẦU UI - Giao diện xem Lịch sử (History Log):
Ngoài việc hiển thị con số mới nhất ở màn hình chính, tôi muốn xây dựng thêm một giao diện (có thể là Dialog, BottomSheet hoặc một tab riêng trên màn hình Admin). Giao diện này sẽ liệt kê Toàn bộ dòng thời gian (Timeline) các lần cập nhật số liệu. Nó phải hiển thị được: Mốc thời gian cập nhật, người cập nhật, và chi tiết các con số của mốc thời gian đó, giúp Admin đối chiếu dữ liệu dễ dàng.

3. Tinh chỉnh cấu trúc Firebase: > Bảng EventDamageStats khi đồng bộ lên Firestore nên được đặt dưới dạng Sub-collection để tối ưu cấu trúc. (Ví dụ đường dẫn: disaster_events/{eventId}/damage_stats).

Với phạm vi đã được cập nhật lại này, hãy bắt tay vào thực thi Phase 1 (Database & Sync) và Phase 2 (Logic & State). Vui lòng sinh ra mã nguồn hoàn chỉnh để thêm bảng EventDamageStats vào app_database.dart, viết Repository/Provider để truy vấn cả "Bản ghi mới nhất" lẫn "Danh sách toàn bộ lịch sử", và hướng dẫn tôi cách cập nhật logic đồng bộ trên Firebase.


# Github Copilot Answer 2:
Updated memory file [](file:///c%3A/Users/hh092/AppData/Roaming/Code/User/workspaceStorage/22fe699dc174314c2ee47e4c9b8ca49d/GitHub.copilot-chat/memory-tool/memories/YTAyZjJhOWMtOTYxMS00YzI3LWI3N2ItYzViOWZjMTQyZWJm/plan.md)

Cảm ơn bạn đã phản hồi. Việc tập trung 100% vào Thống kê thiệt hại, bổ sung bảng Timeline Lịch sử và áp dụng cấu trúc Firebase Sub-collection là những quyết định tối ưu hoàn toàn đúng đắn.

Tuy nhiên, tôi đang hoạt động trong thiết lập là **Planning Agent**. Vai trò duy nhất của tôi là nghiên cứu kiến trúc, định hình thiết kế chung và chốt Phương án Triển khai (Kế hoạch) cùng bạn. Tôi không được phép chỉnh sửa, tạo file thay đổi hay sinh ra các khối code triển khai hệ thống (như yêu cầu sinh mã nguồn Drift, Repository hay logic Firebase). 

Dưới đây là **Bản Kế hoạch Đã Cập Nhật** dựa trên phạm vi (Scope) mới nhất để bạn xem xét chốt lại:

## Plan: Quản lý Thống kê Thiệt hại & Lịch sử

Xây dựng module thống kê thiệt hại lưu trữ theo lịch sử (snapshot) hoàn chỉnh. Dữ liệu được quản lý local bằng Drift và đồng bộ Firebase dưới dạng sub-collection, kèm theo giao diện Timeline xem lại lịch sử thay đổi.

**Steps**

**Phase 1: Lớp Dữ liệu (Drift Database & Firebase Sync)**
1. Mở app_database.dart để tạo bảng `EventDamageStats` dạng snapshot với các field tương ứng (id, eventId, deaths, missing, injured, damagedHouses, propertyDamage, reportedAt, reportedBy).
2. Chạy lệnh codegen (`build_runner`) để Flutter sinh ra database class trong `app_database.g.dart`.
3. Điều chỉnh sync_service.dart, thêm logic xử lý cho bảng `EventDamageStats` ánh xạ thành Firebase sub-collection thông qua đường dẫn `disaster_events/{eventId}/damage_stats`.

**Phase 2: Lớp State & Logic (Riverpod Controllers)**
4. Tạo mới hoặc cập nhật repository (ví dụ ở `lib/features/admin_panel/events/domain/damage_stats_repository.dart`) chứa các hàm `insertStat` (lưu mới), `watchLatestStat(eventId)` (record mới nhất bằng LIMIT 1) và `watchStatHistory(eventId)` (toàn bộ lịch sử).
5. Tạo 2 StreamProviders tương ứng (`latestDamageStatProvider` và `damageStatHistoryProvider`).

**Phase 3: Lớp Giao diện (Admin UI)**
6. Ở admin_event_detail_screen.dart: Bổ sung khu vực UI "Thống kê thiệt hại", tự động consume từ `latestDamageStatProvider`.
7. Bổ sung nút "Xem Lịch sử" trực tiếp trong màn hình chi tiết, cho phép mở 1 Dialog/BottomSheet consume `damageStatHistoryProvider` để render Timeline gồm: Mốc thời gian, người thao tác và chi tiết thiệt hại.
8. Thêm form nhập/sửa gọi lên hành động Insert.

**Relevant files**
- Bản schema: app_database.dart
- Lớp đồng bộ: sync_service.dart
- Màn hình UI chi tiết: admin_event_detail_screen.dart

**Verification**
1. Nhập cập nhật thống kê nhiều lần: Truy vấn Firebase Firestore xác minh chúng được chèn chính xác ở branch sub-collection `disaster_events/{eventId}/damage_stats`.
2. Truy xuất Timeline: Mở BottomSheet/Dialog xem lịch sử, kết quả phải báo đúng số lượng record bản ghi lịch sử, sắp xếp mốc thời gian từ gần nhất ngược về trước.
3. Reload dự án kiểm tra xem UI có lấy số liệu cập nhật chót tự động ngay lần mở hay không.

---
Trạng thái hiện tại: Tôi đã lưu kế hoạch này vào plan.md. Nếu bạn thấy kế hoạch phân chia module này đã sẵn sàng để viết code, xin vui lòng **Chuyển Chế độ sang Agent Code (hoặc ấn nút chuyển giao Hand-off)** nhé! Các lập trình viên Copilot ở chế độ Code sẽ đọc toàn bộ bản kế hoạch này và bắt tay vào sinh mã nguồn cho bạn ngay lập tức.