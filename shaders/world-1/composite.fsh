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

#define minimumLight 1.0 // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define torchlightBrightness 1.0 // [0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define torchlightRadius 1.0 // [0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
//#define YCoCg_Compression

#define maxColorRange 6.0

in vec3 lightVector;
in vec2 texcoord;

in vec3 underwaterColor;
in vec3 torchColor;
in vec3 waterColor;
in vec3 lowlightColor;

uniform sampler2DShadow shadow;		// This is just to prevent rendering entity shadows.

uniform sampler2D gcolor;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;

uniform float near;
uniform float far;
uniform float rainStrength;
uniform float centerDepthSmooth;
uniform float viewWidth;
uniform float viewHeight;

uniform int worldTime;
uniform int isEyeInWater;

uniform ivec2 eyeBrightnessSmooth;

const int 		RGB16 									 = 2;
const int 		RGBA16 									 = 2;

const int 		compositeFormat 				 = RGBA16;
const int 		gcolorFormat 					 	 = RGBA16;
const int 		gaux4Format 						 = RGBA16;

const int 		gaux2Format 					 	 = RGB16;
const int 		gnormalFormat 					 = RGB16;

// Constants
const float		eyeBrightnessHalflife 	 = 7.5f;
const float 	centerDepthHalflife 		 = 2.0f;
const float		ambientOcclusionLevel		 = 0.7f;
const float 	wetnessHalflife					 = 600.0f;
const float 	drynessHalflife					 = 200.0f;
const int			noiseTextureResolution	 = 128;

vec3  normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
vec3  gaux2normal = texture2D(gaux2, texcoord.st).rgb * 2.0 - 1.0;
float depth0 = texture2D(depthtex0, texcoord.st).x;
float depth1 = texture2D(depthtex1, texcoord.st).x;
float skyLightmap = clamp(pow(texture2D(gdepth, texcoord.st).r, 2.0), 0.0, 1.0);
float torchLightmap = clamp(texture2D(gdepth, texcoord.st).g, 0.0, 1.0);
float material = texture2D(gdepth, texcoord.st).b;

float gaux3SkyLightmap = clamp(pow(texture2D(gaux3, texcoord.st).r, 2.0), 0.0, 1.0);
float gaux3TorchLightmap = clamp(texture2D(gaux3, texcoord.st).g, 0.0, 1.0);
float gaux3Material = texture2D(gaux3, texcoord.st).b;

float comp = 1.0 - near / far / far;

bool land	= depth1 < comp;
bool sky	= depth1 > comp;

bool armorGlint = material > 0.49 && material < 0.51;
bool emissiveLight = material > 0.09 && material < 0.11;
bool emissiveHandlight = gaux3Material > 0.59 && gaux3Material < 0.61;
bool water = gaux3Material > 0.09 && gaux3Material < 0.11;
bool ice = gaux3Material > 0.19 && gaux3Material < 0.21;
bool stainedGlass = gaux3Material > 0.29 && gaux3Material < 0.31;
bool hand = gaux3Material > 0.49 && gaux3Material < 0.51;
bool GAUX1 = gaux3Material > 0.0;		// Ask for all materials which are stored in gaux3.

float luma(vec3 clr) {
	return dot(clr, vec3(0.3333));
}

float getTorchLightmap(float lightmap, float skyL) {

	float tRadius = 3.0;	// Higher means lower.
	float tBrightness = 0.5;

	return min(pow(lightmap, tRadius / torchlightRadius) * torchlightBrightness * tBrightness, 1.0);

}

vec3 doEmissiveLight(vec3 clr, vec3 originalClr, bool forHand) {

	float exposure	= 2.0;
	float cover		= 0.4;

	if (forHand) emissiveLight = emissiveHandlight;
	if (emissiveLight) clr = mix(clr.rgb, vec3(1.0) * exposure, max(luma(originalClr.rgb) - cover, 0.0));

	return clr;

}

vec3 lowlightEye(vec3 clr) {

	float desaturationAmount = 0.7;

	desaturationAmount *= mix(1.0, 0.0, torchLightmap);

	return mix(clr, vec3(luma(clr)) * lowlightColor, desaturationAmount);

}

vec3 patternFilter(vec3 clr) {

	// By Chocapic13

	vec2 a0 = texture2D(gcolor, texcoord.st + vec2(1.0 / viewWidth,0.0)).rg;
	vec2 a1 = texture2D(gcolor, texcoord.st - vec2(1.0 / viewWidth,0.0)).rg;
	vec2 a2 = texture2D(gcolor, texcoord.st + vec2(0.0, 1.0 / viewHeight)).rg;
	vec2 a3 = texture2D(gcolor, texcoord.st - vec2(0.0, 1.0 / viewHeight)).rg;

	vec4 lumas = vec4(a0.x, a1.x, a2.x, a3.x);
	vec4 chromas = vec4(a0.y, a1.y, a2.y, a3.y);

	const vec4 threshold = vec4(30.0 / 255.0);

	vec4 w = 1.0 - step(threshold, abs(lumas - clr.x));
	float W = dot(w, vec4(1.0));

	w.x = W == 0.0? 1.0 : w.x;
	W = W == 0.0? 1.0 : W;

	float chroma = dot(w, chromas) / W;


	bool pattern = mod(gl_FragCoord.x, 2.0) == mod(gl_FragCoord.y, 2.0);

	clr.b = chroma;
	clr.rgb = pattern? clr.rbg : clr.rgb;

	return clr;

}

vec3 toRGB(vec3 clr){

	clr.y -= 0.5;
	clr.z -= 0.5;

	return vec3(clr.r + clr.g - clr.b, clr.r + clr.b, clr.r - clr.g - clr.b);

}

void main() {

	vec3 color = texture2D(gcolor, texcoord.st).rgb;

	#ifdef YCoCg_Compression

		color = patternFilter(color);
		color = armorGlint? color.rgb : toRGB(color.rgb);

	#endif

	vec4 fragposition0  = gbufferProjectionInverse * (vec4(texcoord.st, depth0, 1.0) * 2.0 - 1.0);
	     fragposition0 /= fragposition0.w;

	vec4 fragposition1  = gbufferProjectionInverse * (vec4(texcoord.st, depth1, 1.0) * 2.0 - 1.0);
	     fragposition1 /= fragposition1.w;




  vec3 newTorchLightmap					= torchColor * getTorchLightmap(torchLightmap, skyLightmap);
	vec3 newGaux3TorchLightmap		= torchColor * getTorchLightmap(gaux3TorchLightmap, gaux3SkyLightmap);

  vec3 newLightmap = minimumLight * 0.05 + newTorchLightmap;
			 newLightmap = doEmissiveLight(newLightmap, color.rgb, false);

  vec3 newGAUX1Lightmap = minimumLight * 0.05 + newGaux3TorchLightmap;
			 newGAUX1Lightmap = doEmissiveLight(newGAUX1Lightmap, texture2D(gaux1, texcoord.xy).rgb, true);

	color.rgb = lowlightEye(color.rgb);
  color.rgb *= newLightmap;

	if (water) {

		float waterDepth = mix(1.0 - pow(texture2D(gdepth, texcoord.st).r, 1.3), 0.0, 1.0 - gaux3SkyLightmap);

		color.rgb = mix(color.rgb * waterColor, underwaterColor * 0.2, waterDepth);

	}


/* DRAWBUFFERS:30 */

  // 0 = gcolor
  // 1 = gdepth
  // 2 = gnormal
  // 3 = composite
  // 4 = gaux1
  // 5 = gaux2
  // 6 = gaux3
  // 7 = gaux4

  gl_FragData[0] = vec4(color.rgb / maxColorRange, 1.0);
	gl_FragData[1] = vec4(newGAUX1Lightmap / maxColorRange, 1.0);

}
