import 'dart:math' as math;
import 'dart:typed_data';

/// Made-up photos for the own look's tests, as plain pixels: four bytes a
/// pixel, nothing see-through. No image file is kept in the repo.
class SyntheticPhoto {
  const SyntheticPhoto(this.name, this.width, this.height, this.rgba);

  final String name;
  final int width;
  final int height;
  final Uint8List rgba;
}

const int _width = 90;
const int _height = 195;

SyntheticPhoto _photo(
  String name,
  (int, int, int) Function(int x, int y) pixel,
) {
  final rgba = Uint8List(_width * _height * 4);
  var at = 0;
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      final (r, g, b) = pixel(x, y);
      rgba[at++] = r;
      rgba[at++] = g;
      rgba[at++] = b;
      rgba[at++] = 255;
    }
  }
  return SyntheticPhoto(name, _width, _height, rgba);
}

/// The five photos the scrim must hold on, and three more that are closer
/// to a real picture.
List<SyntheticPhoto> syntheticPhotos() {
  final random = math.Random(172);
  return [
    _photo('all white', (x, y) => (255, 255, 255)),
    _photo('all black', (x, y) => (0, 0, 0)),
    _photo(
      'a hard black and white split',
      (x, y) => x < _width ~/ 2 ? (0, 0, 0) : (255, 255, 255),
    ),
    _photo('noise', (x, y) {
      final v = random.nextBool() ? 255 : 0;
      return (v, v, v);
    }),
    _photo(
      'a bright top with a dark bottom',
      (x, y) => y < _height ~/ 2 ? (250, 244, 230) : (12, 14, 20),
    ),
    _photo('a dim room', (x, y) => (60 + x % 30, 48 + y % 20, 40)),
    _photo('one pure colour, red', (x, y) => (255, 0, 0)),
    _photo('a mid grey with one white dot', (x, y) {
      return x == 40 && y == 100 ? (255, 255, 255) : (128, 128, 128);
    }),
  ];
}
