#version 120

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

varying vec4 color;
varying vec4 position2;
varying vec4 worldposition;
varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;
varying vec2 texcoord;
varying vec2 lmcoord;
varying float water;
varying float ice;
varying float stainedGlass;
varying float stainedGlassPlane;

uniform sampler2D texture;
uniform sampler2D noisetex;

uniform float frameTimeCounter;


float waterwaves(vec3 worldPos) {

	float waveSpeed = 0.09;

	if (ice > 0.9) waveSpeed = 0.0;

	worldPos.x += sin(worldPos.z * 2.0 + frameTimeCounter * waveSpeed * 25.0) * 0.1;
	worldPos.z += cos(worldPos.x * 1.5 + frameTimeCounter * waveSpeed * 25.0) * 0.1;

	vec2 coord = vec2(worldPos.xz / 200.0);

	float noise =  texture2D(noisetex, coord * 1.5 + vec2(frameTimeCounter / 20.0 * waveSpeed)).x / 1.5;
		  	noise += texture2D(noisetex, coord * 1.5 - vec2(frameTimeCounter / 15.0 * waveSpeed)).x / 1.5;
		  	noise += texture2D(noisetex, coord * 3.5 + vec2(frameTimeCounter / 12.0 * waveSpeed)).x / 3.5;
		  	noise += texture2D(noisetex, coord * 3.5 - vec2(frameTimeCounter / 9.0 * waveSpeed)).x / 3.5;
		  	noise += texture2D(noisetex, coord * 7.0 + vec2(frameTimeCounter / 6.0 * waveSpeed)).x / 7.0;
		  	noise += texture2D(noisetex, coord * 7.0 - vec2(frameTimeCounter / 4.0 * waveSpeed)).x / 7.0;

	return noise / 6.0;

}

vec3 waterwavesToNormal() {

  float deltaPos = 0.1;
	float h0 = waterwaves(worldposition.xyz);
	float h1 = waterwaves(worldposition.xyz + vec3(deltaPos, 0.0, 0.0));
	float h2 = waterwaves(worldposition.xyz + vec3(-deltaPos, 0.0, 0.0));
	float h3 = waterwaves(worldposition.xyz + vec3(0.0, 0.0, deltaPos));
	float h4 = waterwaves(worldposition.xyz + vec3(0.0, 0.0, -deltaPos));

	float xDelta = ((h1 - h0) + (h0 - h2)) / deltaPos;
	float yDelta = ((h3 - h0) + (h0 - h4)) / deltaPos;

	return normalize(vec3(xDelta, yDelta, 1.0 - xDelta * xDelta - yDelta * yDelta));

}

vec4 normalMapping() {

	float bumpMult = 0.5;

	float NdotE = abs(dot(normal, normalize(position2.xyz)));

	bumpMult *= NdotE;

  vec4 result = vec4(vec3(normal) * 0.5 + 0.5, 1.0);

  if (water > 0.9 || ice > 0.9) {

  	vec3 bump  = waterwavesToNormal();
  			 bump *= vec3(bumpMult) + vec3(0.0, 0.0, 1.0 - bumpMult);

  	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
  						  					tangent.y, binormal.y, normal.y,
  						  					tangent.z, binormal.z, normal.z);

	  result = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);

  }

  return result;

}


void main() {

  vec4 baseColor = texture2D(texture, texcoord.st) * color;

	// This is actually for the water which is behind stainedGlass and ice.
  if (water > 0.9) baseColor = vec4(vec3(0.3, 0.65, 1.0) * 0.2, 1.0);

  float material = 0.0;
  if (water > 0.9) material = 0.1;
  if (ice > 0.9) material = 0.2;
  if (stainedGlass > 0.9) material = 0.3;
  if (stainedGlassPlane > 0.9) material = 0.3;

/* DRAWBUFFERS:465 */

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
  gl_FragData[2] = normalMapping();

}
