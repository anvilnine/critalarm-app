#include <flutter/runtime_effect.glsl>

// Fades a blurred copy of the screen in towards one edge.
//
// Runs as the outer half of ImageFilter.compose, after one plain blur, inside
// a BackdropFilter. The input is the blurred screen, in screen pixels. The
// output alpha is how much blur shows: full at the screen edge, nothing at the
// inner end of the band, so the sharp screen shows through where it fades.

// Set by the engine: size of the input, which is the whole screen.
uniform vec2 u_size;
// y of the screen edge and y of the inner end of the band, in device pixels.
uniform vec2 u_band;

uniform sampler2D u_input;

out vec4 frag_color;

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = p / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  // 1 at the screen edge, 0 at the inner end, whichever way the band runs.
  float t = clamp((p.y - u_band.y) / (u_band.x - u_band.y), 0.0, 1.0);
  // Smoothstep keeps both ends flat, so there is no visible start.
  float w = t * t * (3.0 - 2.0 * t);
  // The input is premultiplied, so scaling the whole colour fades it.
  frag_color = texture(u_input, uv) * w;
}
