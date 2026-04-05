#version 400 compatibility

/*



			███████ ███████ ███████ ███████ █
			█          █    █     █ █     █ █
			███████    █    █     █ ███████ █
			      █    █    █     █ █
			███████    █    ███████ █       █

	Before you change anything here, please keep in mind that
	you are allowed to modify my shaderpack ONLY for yourself!

	Please read my agreement for more informations!
		- http://dedelner.net/agreement/



*/

in vec4 color;
in vec3 normal;
in vec2 texcoord;
in vec2 lmcoord;

uniform sampler2D texture;

uniform int heldBlockLightValue;
uniform int heldItemId;


vec4 toYCoCg(vec4 clr) {

	vec3 YCoCg = vec3(0.0);

	YCoCg.r =  0.25	* clr.r + 0.5 * clr.g + 0.25 * clr.b;
	YCoCg.g =  0.5	* clr.r - 0.5 * clr.b + 0.5;
	YCoCg.b = -0.25	* clr.r + 0.5 * clr.g - 0.25 * clr.b + 0.5;

	bool pattern = mod(gl_FragCoord.x, 2.0) == mod(gl_FragCoord.y, 2.0);

	YCoCg.g = pattern? YCoCg.b : YCoCg.g;

	return vec4(YCoCg, clr.a);

}

void main() {

  vec4 baseColor = texture2D(texture, texcoord.st) * color;
       //baseColor = toYCoCg(baseColor);

  vec4 directSunlight = vec4(vec3(normal) * 0.5 + 0.5, 1.0);


  float material = 0.5;
  if (bool(heldBlockLightValue)) material = 0.6;

/* DRAWBUFFERS:4657 */

  // 0 = gcolor
  // 1 = gdepth
  // 2 = gnormal
  // 3 = composite
  // 4 = gaux1
  // 5 = gaux2
  // 6 = gaux3
  // 7 = gaux4

  gl_FragData[0] = baseColor;
  gl_FragData[1] = vec4(lmcoord.t, lmcoord.s, material, 1.0);
  gl_FragData[2] = directSunlight;
  gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);

}
