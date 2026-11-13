import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A rasterized image of the whole view, kept as raw RGBA bytes.
///
/// Used to prove with real pixels — not just `getRect`, which reads the paint
/// transform after the frame finished — that a page is drawn where it belongs
/// on *every* frame the router produces.
class Screenshot {
  Screenshot(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;

  /// Number of pixels that differ from [other] inside [region] (whole image by
  /// default).
  int diff(Screenshot other, {Rect? region}) {
    expect(other.width, width, reason: 'screenshots of different sizes');
    expect(other.height, height, reason: 'screenshots of different sizes');
    final Rect r =
        region ?? Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final int x0 = r.left.round().clamp(0, width);
    final int y0 = r.top.round().clamp(0, height);
    final int x1 = r.right.round().clamp(0, width);
    final int y1 = r.bottom.round().clamp(0, height);
    var count = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final int i = (y * width + x) * 4;
        if (bytes[i] != other.bytes[i] ||
            bytes[i + 1] != other.bytes[i + 1] ||
            bytes[i + 2] != other.bytes[i + 2] ||
            bytes[i + 3] != other.bytes[i + 3]) {
          count++;
        }
      }
    }
    return count;
  }
}

/// Captures the current frame of the view.
Future<Screenshot> capture(WidgetTester tester) async {
  final view = tester.binding.renderViews.first;
  final OffsetLayer layer = view.debugLayer! as OffsetLayer;
  late Screenshot shot;
  await tester.runAsync(() async {
    final ui.Image image = await layer.toImage(Offset.zero & view.size);
    final ByteData? data = await image.toByteData();
    shot = Screenshot(data!.buffer.asUint8List(), image.width, image.height);
    image.dispose();
  });
  return shot;
}

/// Pumps one frame at a time (16 ms), capturing each, until two consecutive
/// frames are identical (the transition settled) or [max] frames were taken.
Future<List<Screenshot>> captureFrames(
  WidgetTester tester, {
  int max = 30,
}) async {
  final shots = <Screenshot>[];
  Screenshot previous = await capture(tester);
  for (var i = 0; i < max; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final screenshot = await capture(tester);
    shots.add(screenshot);
    if (i >= 1 && screenshot.diff(previous) == 0) break;
    previous = screenshot;
  }
  return shots;
}
