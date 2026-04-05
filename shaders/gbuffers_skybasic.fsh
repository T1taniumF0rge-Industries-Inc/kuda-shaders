#version 120

varying vec4 color;
varying vec2 texcoord;


void main() {


/* DRAWBUFFERS:0 */

  // 0 = gcolor
  // 1 = gdepth
  // 2 = gnormal
  // 3 = composite
  // 4 = gaux1
  // 5 = gaux2
  // 6 = gaux3
  // 7 = gaux4

  gl_FragData[0] = color;

}
