#!/usr/bin/env bash
# Launches the app needed for the manual test cases in MANUAL_TESTS.md.
#
#   tool/manual_test.sh <target> [device-id]
#
# Targets
#   linux         example app, Linux window            (group A)
#   android       example app, Android device/emulator (group B)
#   web           example app, web server on :8080      (group C)
#   lab-linux     manual lab, Linux window              (group D)
#   lab-web       manual lab, web server on :8081       (group E)
#   lab-android   manual lab, Android device/emulator   (group F)
#   plain-android plain Navigator control app, Android  (control for F1)
#   devices       list the connected devices
#
# [device-id] is only used by the android targets (see `devices`); without it
# Flutter asks which connected device to use.
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:-}"
device="${2:-}"

# Without a device id Flutter asks which connected device to use.
android_args=()
if [[ -n "$device" ]]; then
  android_args=(-d "$device")
fi

case "$target" in
  linux)
    exec fvm flutter run -d linux
    ;;
  android)
    exec fvm flutter run ${android_args[@]+"${android_args[@]}"}
    ;;
  web)
    echo ">>> Open http://localhost:8080 in your browser once the server is ready."
    exec fvm flutter run -d web-server --web-port 8080
    ;;
  lab-linux)
    exec fvm flutter run -d linux -t lib/manual_lab.dart
    ;;
  lab-web)
    echo ">>> Open http://localhost:8081 in your browser once the server is ready."
    exec fvm flutter run -d web-server --web-port 8081 -t lib/manual_lab.dart
    ;;
  lab-android)
    exec fvm flutter run ${android_args[@]+"${android_args[@]}"} -t lib/manual_lab.dart
    ;;
  plain-android)
    exec fvm flutter run ${android_args[@]+"${android_args[@]}"} -t lib/manual_plain.dart
    ;;
  devices)
    exec fvm flutter devices
    ;;
  *)
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
