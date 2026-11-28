#!/usr/bin/env bash
# Vercel 建置：下載固定版本的 Flutter，建置網頁版放進 public/（vercel.json 的 outputDirectory）。
# 解籤 API（api/interpret.js）已預先打包，不需在這裡處理。網頁版和 API 同網域，App 不用設定網址。
set -euo pipefail

FLUTTER_VERSION=3.50.1 # 與本機開發同版本
FLUTTER_DIR="${HOME}/flutter-${FLUTTER_VERSION}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Flutter 下載網頁引擎時要解 zip；Vercel 的建置環境（Amazon Linux 2023）預設可能沒有 unzip。
if ! command -v unzip >/dev/null 2>&1; then
  echo "安裝 unzip"
  dnf install -y unzip >/dev/null
fi

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "下載 Flutter ${FLUTTER_VERSION}"
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "${HOME}"
  mv "${HOME}/flutter" "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"
# 建置環境以 root 執行，Flutter 的 git 會拒絕「不同擁有者」的目錄
git config --global --add safe.directory '*'

flutter config --no-analytics >/dev/null
flutter --version

cd "${ROOT}/app"
flutter pub get
flutter build web --release

rm -rf "${ROOT}/public"
cp -r "${ROOT}/app/build/web" "${ROOT}/public"
echo "網頁版已放進 public/"
