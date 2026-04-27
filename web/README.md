# Flutter Web — Drift (SQLite)

Ứng dụng dùng **Drift** trên web cần hai file trong thư mục này:

- **sqlite3.wasm** — module WebAssembly của SQLite (từ [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases), bản 3.x khớp với drift 2.32).
- **drift_worker.js** — worker của Drift (từ [drift releases](https://github.com/simolus3/drift/releases)).

## Cách lấy file

Từ **thư mục gốc** project, chạy:

```powershell
.\scripts\download_web_assets.ps1
```

Hoặc tải thủ công và đặt vào `web/`:

- [sqlite3.wasm (3.1.6)](https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.1.6/sqlite3.wasm)
- [drift_worker.js (2.32.0)](https://github.com/simolus3/drift/releases/download/drift-2.32.0/drift_worker.js)

## Lỗi "Incorrect response MIME type. Expected 'application/wasm'"

- **Nguyên nhân thường gặp:** Thiếu `sqlite3.wasm` (và/hoặc `drift_worker.js`). Server trả về trang HTML thay vì file .wasm → trình duyệt báo sai MIME type.
- **Cách xử lý:** Đảm bảo đã có đủ hai file trên trong `web/` (chạy script ở trên).
- `flutter run -d chrome` mặc định đã serve `.wasm` với đúng MIME type; khi deploy, cấu hình server (Firebase, nginx, v.v.) để gửi `Content-Type: application/wasm` cho file `.wasm`.
