import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A rasterized image of the whole view, kept as raw RGBA bytes.
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

/// Number of pixels that differ from [other] outside [pane], ignoring every
/// pixel that overlaps one of [except].
///
/// A pixel that straddles the edge of [pane] is partly inside it, so it is not
/// required to stay identical (otherwise the pane's own anti-aliased border
/// would count as "outside"). Pixels touching [except] are skipped too: the
/// example tints the selected list row, which is legitimate chrome.
int diffOutsideExcept(
  Screenshot a,
  Screenshot b, {
  required Rect pane,
  List<Rect> except = const <Rect>[],
}) {
  expect(a.width, b.width, reason: 'screenshots of different sizes');
  expect(a.height, b.height, reason: 'screenshots of different sizes');
  final double left = pane.left.floorToDouble();
  final double top = pane.top.floorToDouble();
  final double right = pane.right.ceilToDouble();
  final double bottom = pane.bottom.ceilToDouble();
  var count = 0;
  for (var y = 0; y < a.height; y++) {
    for (var x = 0; x < a.width; x++) {
      final Rect pixel = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
      // Fully inside the pane rectangle: its pixels belong to the transition.
      if (pixel.left >= left &&
          pixel.right <= right &&
          pixel.top >= top &&
          pixel.bottom <= bottom) {
        continue;
      }
      if (except.any(pixel.overlaps)) continue;
      final int i = (y * a.width + x) * 4;
      if (a.bytes[i] != b.bytes[i] ||
          a.bytes[i + 1] != b.bytes[i + 1] ||
          a.bytes[i + 2] != b.bytes[i + 2] ||
          a.bytes[i + 3] != b.bytes[i + 3]) {
        count++;
      }
    }
  }
  return count;
}

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
