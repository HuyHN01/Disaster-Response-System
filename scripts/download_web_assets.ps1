# Download Drift web assets (sqlite3.wasm + drift_worker.js) for Flutter web.
# Run from project root: .\scripts\download_web_assets.ps1
# Required for: "Incorrect response MIME type. Expected 'application/wasm'"

$projectRoot = Split-Path -Parent $PSScriptRoot
$webDir = Join-Path $projectRoot "web"
if (-not (Test-Path $webDir)) {
    Write-Error "web/ directory not found. Run from project root."
    exit 1
}

$sqlite3Wasm = "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.1.6/sqlite3.wasm"
$driftWorker = "https://github.com/simolus3/drift/releases/download/drift-2.32.0/drift_worker.js"

Write-Host "Downloading sqlite3.wasm..."
Invoke-WebRequest -Uri $sqlite3Wasm -OutFile (Join-Path $webDir "sqlite3.wasm") -UseBasicParsing

Write-Host "Downloading drift_worker.js..."
Invoke-WebRequest -Uri $driftWorker -OutFile (Join-Path $webDir "drift_worker.js") -UseBasicParsing

Write-Host "Done. Files in web/: sqlite3.wasm, drift_worker.js"
Write-Host "Run app: flutter run -d chrome"
