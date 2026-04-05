#version 400 compatibility
#extension GL_ARB_shader_texture_lod : enable

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

#define normalMapping
#define normalMapStrength	1.0	// [0.6 0.8 1.0 1.2 1.4]
//#define parallaxOcclusionMapping
#define pomDepth 1.5 // [0.5 1.5 2.5 3.5]
//#define YCoCg_Compression

in vec4 color;
in vec4 vtexcoordam;
in vec4 vtexcoord;
in vec4 worldposition;
in vec3 viewVector;
in vec3 tangent;
in vec3 normal;
in vec3 binormal;
in vec2 texcoord;
in vec2 lmcoord;
in float emissiveLight;
in float dist;
uniform float wetness;
uniform float frameTimeCounter;

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec3 upPosition;

float skyLightmap = clamp(pow(lmcoord.t, 2.0), 0.0, 1.0);

vec2 dcdx = dFdx(vtexcoord.st * vtexcoordam.pq);
vec2 dcdy = dFdy(vtexcoord.st * vtexcoordam.pq);


vec4 readNormal(in vec2 coord) {
	return texture2DGradARB(normals, fract(coord) * vtexcoordam.pq + vtexcoordam.st, dcdx, dcdy);
}

vec4 readTexture(in vec2 coord) {
	return texture2DGradARB(texture, fract(coord) * vtexcoordam.pq + vtexcoordam.st, dcdx, dcdy);
}

mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
											tangent.y, binormal.y, normal.y,
											tangent.z, binormal.z, normal.z);

vec2 doParallaxMapping(vec2 coord) {

	float pomSamples = 256.0;
	float maxOcclusionDistance = 32.0;
	float mixOcclusionDistance = 28.0;
	int   maxOcclusionPoints = 256;

	vec2 newCoord = coord;

	#ifdef parallaxOcclusionMapping

		vec3 vwVector = normalize(tbnMatrix * viewVector);

		vec3 intervalMult = vec3(1.0, 1.0, 10.0 / pomDepth) / pomSamples;

		if (dist < maxOcclusionDistance) {

			if (vwVector.z < 0.0 && readNormal(vtexcoord.st).a < 0.99 && readNormal(vtexcoord.st).a > 0.01) {
				vec3 interval = vwVector.xyz * intervalMult;
				vec3 coord = vec3(vtexcoord.st, 1.0);

				for (int loopCount = 0; (loopCount < maxOcclusionPoints) && (readNormal(coord.st).a < coord.p); ++loopCount) {
					coord = coord + interval;
				}

				float mincoord = 1.0 / 4096.0;

				// Don't wrap around top of tall grass/flower
				if (coord.t < mincoord) {
					if (readTexture(vec2(coord.s, mincoord)).a == 0.0) {
						coord.t = mincoord;
						discard;
					}
				}

				newCoord = mix(fract(coord.st) * vtexcoordam.pq + vtexcoordam.st, newCoord, max(dist - mixOcclusionDistance, 0.0) / (maxOcclusionDistance - mixOcclusionDistance));

			}

		}

	#endif

	return newCoord;

}

float waterWaves(vec3 worldPos) {

	float wave = 0.0;

	float waveSpeed = 2.0;

	wave += texture2D(noisetex, worldPos.xz * 0.07 + vec2(frameTimeCounter / 50.0 * waveSpeed)).x * 0.2;
	wave += texture2D(noisetex, worldPos.xz * 0.07 - vec2(frameTimeCounter / 50.0 * waveSpeed)).x * 0.2;


	return wave * 0.1;

}

vec4 doNormalMapping(vec2 coord) {

	vec4 result = vec4(vec3(normal) * 0.5 + 0.5, 1.0);

	#ifdef normalMapping

		vec3 specularity = texture2DGradARB(specular, coord.st, dcdx, dcdy).rgb;

		float atten = 1.0 - specularity.b * 0.86;

		float bumpMult = normalMapStrength * atten;

		vec3 bump  = texture2DGradARB(normals, coord, dcdx, dcdy).rgb * 2.0 - 1.0;
				 bump *= vec3(bumpMult) + vec3(0.0, 0.0, 1.0 - bumpMult);

		result = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);

	#endif

	return result;

}

vec3 getSpecular(vec2 coord) {

	vec3 specularity = texture2DGradARB(specular, coord.st, dcdx, dcdy).rgb;

	return vec3(specularity.rg, 0.0);

}

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

  vec2 adjustedTexcoord = vtexcoord.st * vtexcoordam.pq + vtexcoordam.st;
			 adjustedTexcoord = doParallaxMapping(adjustedTexcoord);

	vec4 baseColor = texture2D(texture, adjustedTexcoord.st) * color;

	#ifdef YCoCg_Compression
		baseColor = toYCoCg(baseColor);
	#endif



  float material = 0.0;

	if (emissiveLight > 0.9) material = 0.1;

/* DRAWBUFFERS:0127 */

  // 0 = gcolor
  // 1 = gdepth
  // 2 = gnormal
  // 3 = composite
  // 4 = gaux1
  // 5 = gaux2
  // 6 = gaux3
  // 7 = gaux4

  gl_FragData[0] = baseColor;
  gl_FragData[1] = vec4(lmcoord.t, lmcoord.s, material, 1.0);   // Alpha channel should have the value 1.0!
  gl_FragData[2] = doNormalMapping(adjustedTexcoord.st);
	gl_FragData[3] = vec4(getSpecular(adjustedTexcoord).rgb, 1.0);

}
