#version 400 compatibility
//#extension GL_ARB_gpu_shader5 : enable

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

#define softShadows
#define shadowSamples 8 // [8 28] More samples means softer shadows but also more performance hit.
#define shadowAcneFixMul 1.0	// [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 4.0 6.0 8.0 10.0 12.0] Will eliminate self-shadowing pixels but also causes "Peter panning"/cutting of the shadows.
#define shadowMapBias 0.8 // [0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95] A higher value means sharper shadows, but also less detail in the distance. You may have to increase shadowAcneFixMul.
//#define shakingCamera
#define windSpeed 1.0 // [0.1 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6]
#define volumetricLight
	#define vlQuality 0.75 // [0.3 0.5 0.75 1.0 1.5 2.0]
	#define vlRenderDistance 30.0 // [20.0 30.0 40.0 50.0 60.0]
#define waterShader
#define waterCaustics
#define minimumLight 1.0 // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define torchlightBrightness 1.0 // [0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define torchlightRadius 1.0 // [0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
//#define depthOfField
//#define YCoCg_Compression		// Can gain some FPS back, but armor glint wouldn't be rendered correctly then!

#define maxColorRange 6.0

in vec3 lightVector;
in vec2 texcoord;
in float weatherRatio;

in vec3 ambientColor;
in vec3 sunlightColor;
in vec3 underwaterColor;
in vec3 torchColor;
in vec3 waterColor;
in vec3 lowlightColor;

in float TimeBeforeSunrise;
in float TimeSunrise;
in float TimeSunrise2;
in float TimeNoon;
in float TimeSunset;
in float TimeSunset2;
in float TimeAfterSunset;
in float TimeMidnight;
in float TimeMidnight2;
in float TimeDay;
in float DayToNightFading;

uniform sampler2DShadow shadow;

uniform sampler2D gcolor;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform mat4 gbufferModelView;

uniform vec3 sunPosition;
uniform vec3 cameraPosition;

uniform float near;
uniform float far;
uniform float rainStrength;
uniform float centerDepthSmooth;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform int worldTime;
uniform int isEyeInWater;


const int 		RGB16 									 = 0;
const int 		RGBA16 									 = 0;

const int 		compositeFormat 				 = RGBA16;
const int 		gcolorFormat 					 	 = RGBA16;
const int 		gaux4Format 						 = RGBA16;

const int 		gaux2Format 					 	 = RGB16;
const int 		gnormalFormat 					 = RGB16;

// Constants
const float   sunPathRotation          = -35.0f;
const int 		shadowMapResolution 	   = 2048;	// [512 1024 2048 4096]
const float 	shadowDistance					 = 120.0f;	// [60.0f 80.0f 120.0f 160.0f] Increasing the shadow distance will reduce the shadow quality!
const float 	shadowIntervalSize			 = 4.0f;
const bool 		shadowHardwareFiltering0 = true;
const float		eyeBrightnessHalflife 	 = 7.5f;
const float		ambientOcclusionLevel		 = 0.7f;
const float 	wetnessHalflife					 = 600.0f;
const float 	drynessHalflife					 = 200.0f;
const int			noiseTextureResolution	 = 128;

#ifdef depthOfField
	const float 	centerDepthHalflife = 2.0f;	// [0.0f 0.2f 0.4f 0.6f 0.8f 1.0f 1.2f 1.4f 1.6f 1.8f 2.0f] Transition for focus.
#endif


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
bool glowingEyes = material > 0.39 && material < 0.41;
bool clouds = material > 0.29 && material < 0.31;
bool translucent = material > 0.19 && material < 0.21 || clouds;
bool emissiveLight = material > 0.09 && material < 0.11;
bool emissiveHandlight = gaux3Material > 0.59 && gaux3Material < 0.61;
bool water = gaux3Material > 0.09 && gaux3Material < 0.11;
bool ice = gaux3Material > 0.19 && gaux3Material < 0.21;
bool stainedGlass = gaux3Material > 0.29 && gaux3Material < 0.31;
bool hand = gaux3Material > 0.49 && gaux3Material < 0.51;
bool GAUX1 = gaux3Material > 0.0;		// Ask for all materials which are stored in gaux3 for gaux1.

bool reflectiveBlocks = water || ice || stainedGlass;

float globalLightmap = reflectiveBlocks || hand? gaux3SkyLightmap : skyLightmap;

float directNormal = max(dot(normal, lightVector), 0.0);
float directGAUX2 = max(dot(gaux2normal, lightVector), 0.0);

const vec2 circlePattern8[8] = vec2[8](vec2(1.0, 0.0),
									   									 vec2(0.0, 1.0),

									   							 	   vec2(-1.0, 0.0),
									   							 		 vec2(0.0, -1.0),

																			 vec2(1.0, 0.5),
									   							 		 vec2(1.0, -0.5),

																			 vec2(-1.0, 0.5),
									   							 		 vec2(-1.0, -0.5));

const vec2 circlePattern[28] = vec2[28](vec2(1.0, 0.0),
										vec2(0.0, 1.0),

										vec2(-1.0, 0.0),
										vec2(0.0, -1.0),

										vec2(1.0, 0.5),
										vec2(0.5, 1.0),

										vec2(-1.0, 0.5),
										vec2(0.5, -1.0),

										vec2(1.0, -0.5),
										vec2(-0.5, 1.0),

										vec2(-1.0, -0.5),
										vec2(-0.5, -1.0),

										vec2(-0.8, 0.8),
										vec2(0.8, -0.8),

										vec2(0.8, 0.8),
										vec2(-0.8, -0.8),

										vec2(1.2, 0.0),
										vec2(0.0, 1.2),

										vec2(-1.2, 0.0),
										vec2(0.0, -1.2),

										vec2(0.5, 0.0),
										vec2(0.0, 0.5),

										vec2(-0.5, 0.0),
										vec2(0.0, -0.5),

										vec2(0.5, 0.5),
										vec2(-0.5, -0.5),

										vec2(0.5, -0.5),
										vec2(-0.5, 0.5));

float luma(vec3 clr) {
	return dot(clr, vec3(0.3333));
}

float linearDepth(float depth){
	return 2.0 * (near * far) / (far + near - (depth) * (far - near));
}

float depthX(float x){
	return ((far * (x - near)) / (x * (far - near)));
}

float rand(vec2 co) {

  const float a = 12.9898;
  const float b = 78.233;
  const float c = 43758.5453;
	const float pi = 3.14159265359;

  float dt = dot(co.xy, vec2(a, b));
  float sn = mod(dt, pi);

  return fract(sin(sn) * c);

}

float getTorchLightmap(float lightmap, float skyL) {

	float tRadius = 3.0;	// Higher means lower.
	float tBrightness = 0.5;

	tRadius *= mix(1.0, 5.0, skyL * TimeDay);

	return min(pow(lightmap, tRadius / torchlightRadius) * torchlightBrightness * tBrightness, 1.0);

}

vec3 doEmissiveLight(vec3 clr, vec3 originalClr, bool forHand) {

	float exposure	= 2.5;
	float cover		= 0.4;

	if (forHand) emissiveLight = emissiveHandlight;
	if (emissiveLight) clr = mix(clr.rgb, vec3(1.0) * exposure, max(luma(originalClr.rgb) - cover, 0.0));

	return clr;

}

vec3 lowlightEye(vec3 clr) {

	float desaturationAmount = 0.7;

	desaturationAmount *= mix(1.0, mix(0.0, 1.0, TimeMidnight), skyLightmap);
	desaturationAmount *= mix(1.0, 0.0, torchLightmap);

	return mix(clr, vec3(luma(clr)) * mix(lowlightColor, vec3(1.0), skyLightmap), desaturationAmount);

}

float waterWaves(vec3 worldPos) {

	float wave = 0.0;

	#if defined waterShader && defined waterCaustics

		float waveSpeed = 1.0;

		if (ice) waveSpeed = 0.0;

		worldPos.x += sin(worldPos.z * 1.5 + frameTimeCounter * waveSpeed * 2.5) * 0.3;
		worldPos.z += worldPos.y;
		worldPos.x += worldPos.y;

		wave  = texture2D(noisetex, worldPos.xz * 0.025 + vec2(frameTimeCounter * 0.02 * waveSpeed * windSpeed)).x * 0.2;
		wave += sin((worldPos.x + worldPos.z) * 4.0 - frameTimeCounter * 6.0 * waveSpeed) * 0.03;
		wave += sin((worldPos.x + worldPos.z) * 2.0 - frameTimeCounter * 3.0 * waveSpeed) * 0.05;
		wave += sin((worldPos.x + worldPos.z) * 1.0 - frameTimeCounter * 1.0 * waveSpeed) * 0.08;

		wave += sin((worldPos.x - worldPos.z) * 2.0 - frameTimeCounter * 6.0 * waveSpeed) * 0.05;
		wave += sin((worldPos.x - worldPos.z) * 1.0 - frameTimeCounter * 3.0 * waveSpeed) * 0.08;

	#endif

	return clamp(wave, 0.0, 1.0);

}

float getWaterCaustics(vec3 fragpos) {

	float result = 0.0;

	#ifdef waterCaustics

		vec4 worldPos = gbufferModelViewInverse * vec4(fragpos, 1.0) + vec4(cameraPosition, 0.0);

		float deltaPos = 0.4;
		float h0 = waterWaves(worldPos.xyz);
		float h1 = waterWaves(worldPos.xyz - vec3(deltaPos, 0.0, 0.0));
		float h2 = waterWaves(worldPos.xyz - vec3(0.0, 0.0, deltaPos));

		float dX = ((h0-h1))/deltaPos;
		float dY = ((h0-h2))/deltaPos;

		vec3 waterRefract = normalize(vec3(dX, dY, 1.0));

		result = water? pow(luma(waterRefract), 5.0) * 25.0 : 0.0;

		if (bool(isEyeInWater)) {
			result = water? 0.0 : pow(luma(waterRefract), 5.0) * 25.0;
		}

	#endif

	return clamp(result, 0.0, 1.0);

}

float castShadows(vec3 fragpos, float direct, bool forGAUX1) {

	float shadowSmoothnessFactor = 0.65;

	if (shadowSamples == 28.0) {
		shadowSmoothnessFactor *= 1.5;
		shadowSmoothnessFactor = mix(shadowSmoothnessFactor, shadowSmoothnessFactor * 5.0, weatherRatio);
	}

	if (bool(isEyeInWater)) fragpos.xy *= 0.81;

	vec4 worldPos = gbufferModelViewInverse * vec4(fragpos, 1.0);

	#ifdef shakingCamera
		worldPos -= vec4(0.02 * sin(frameTimeCounter * 2.0), 0.005 * cos(frameTimeCounter * 3.0), 0.0, 0.0) * gbufferModelView;
	#endif

  worldPos = shadowModelView * worldPos;
	worldPos = shadowProjection * worldPos;
	worldPos /= worldPos.w;

	float dist = length(fragpos.xyz);
	float distb = length(worldPos.st);
	float distortFactor = mix(1.0, distb, shadowMapBias);

	worldPos.xy /= distortFactor;

	float shading = 1.0;

	float step = 1.0 / float(shadowMapResolution);

	float shadowAcneFix = shadowAcneFixMul * (2048 / (shadowMapResolution > 2048? 2048 : shadowMapResolution));

	float shadowFade = clamp((1.0 - dist / shadowDistance) * 12.0, 0.0, 1.0);

	if (forGAUX1) {
		translucent = false;
		direct = !GAUX1? directNormal : directGAUX2;
	}

	shading = 1.0;

	if (max(abs(worldPos.x), abs(worldPos.y)) < 0.99 && dist < shadowDistance) {

		float diffthresh = translucent? 0.001 : hand? 0.0025 : distortFactor * distortFactor * (0.004 * shadowAcneFix * tan(acos(direct)) + 0.0004 * shadowAcneFix);

		worldPos = worldPos * 0.5 + vec4(0.5, 0.5, 0.5 - diffthresh, 0.5);

		#ifdef softShadows

			if (!forGAUX1) {

				shading = 0.0;

				for (int i = 0; i < int(shadowSamples); i++) {

					vec2 coords = circlePattern8[i];
					if (shadowSamples == 28.0) coords = circlePattern[i];

					shading += shadow2D(shadow, vec3(worldPos.st + coords * step * shadowSmoothnessFactor, worldPos.z)).x;

				}

				shading /= shadowSamples;

			} else {

				shading = shadow2D(shadow, vec3(worldPos.st, worldPos.z)).x;

			}

		#else

			shading = shadow2D(shadow, vec3(worldPos.st, worldPos.z)).x;

		#endif

		shading = mix(1.0, shading, shadowFade);

	}

	direct = max(direct, float(translucent) * mix(0.25, 0.75, shadowFade));

	shading *= direct;
	shading *= 1.0 - weatherRatio;
	shading *= DayToNightFading;

  return shading;

}

float bouncedLight() {

	float reversedNormal = pow(max(dot(normal, -lightVector), 0.0), 0.75);

 	reversedNormal *= 1.0 - weatherRatio * 0.5;
	reversedNormal *= DayToNightFading;

	return reversedNormal;

}

float getVolumetricRays() {

  float vlRays = sky? 0.5 : 0.0;

	#ifdef volumetricLight

		vlRays = 0.0;

		float vlRenderQuality = 1.0 / vlQuality;

		float noise = rand(texcoord.st) * vlRenderQuality - 0.01;

	  for (noise; noise < distance(texcoord.x, vlRenderDistance);) {

			if (linearDepth(depth1 * 2.0 - 1.0) < noise) break;

			vec4 fragpos = gbufferProjectionInverse * vec4(vec3(texcoord.st * 2.0 - 1.0, depthX(noise) * 2.0 - 1.0), 1.0);
					 fragpos /= fragpos.w;

			if (bool(isEyeInWater)) fragpos.xy *= 0.81;

			vec4 worldPos = gbufferModelViewInverse * vec4(fragpos.xyz, 1.0);

		  worldPos = shadowModelView * worldPos;
			worldPos = shadowProjection * worldPos;
			worldPos /= worldPos.w;

			float distb = length(worldPos.st);
			float distortFactor = mix(1.0, distb, shadowMapBias);

			worldPos.xy /= distortFactor;

			float diffthresh = distortFactor * distortFactor * 0.0044;

			worldPos = worldPos * 0.5 + vec4(0.5, 0.5, 0.5 - diffthresh, 0.5);

			vlRays += shadow2D(shadow, vec3(worldPos.st, worldPos.z)).x;

			noise += vlRenderQuality;

	  }

		vlRays /= (vlRenderDistance > 40.0? vlRenderDistance : 40.0 / vlRenderQuality);	// 40.0 is the default render distance.

	#endif

  return vlRays;

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


  float ambientStrength					= 0.55;
  float directLightStrength			= 1.2;
  float bouncedLightStrength		= 0.11;


	// Light scattering.
	float sunVector = max(dot(normalize(fragposition0.xyz), normalize(sunPosition)), 0.0);
	float sun	= pow(sunVector, 5.0);

	directLightStrength *= mix(1.0, 1.7, sun);


	float shading1 = castShadows(fragposition1.xyz, directNormal, false);
	float shading2 = castShadows(fragposition0.xyz, directGAUX2, true);

  vec3 newTorchLightmap					= torchColor * getTorchLightmap(torchLightmap, skyLightmap);
	vec3 newGaux3TorchLightmap		= torchColor * getTorchLightmap(gaux3TorchLightmap, gaux3SkyLightmap);
  vec3 ambientLightmap					= ambientColor * ambientStrength;
  vec3 sunlightLightmap					= sunlightColor * directLightStrength;
	vec3 causticsSunlightLightmap	= getWaterCaustics(fragposition1.xyz) * sunlightColor * directLightStrength;
  vec3 bouncedSunlightLightmap	= sunlightColor * bouncedLight() * directLightStrength * bouncedLightStrength;

  vec3 newLightmap = minimumLight * 0.02 + (ambientLightmap + (sunlightLightmap + causticsSunlightLightmap) * shading1 + bouncedSunlightLightmap) * skyLightmap + newTorchLightmap;
			 newLightmap = doEmissiveLight(newLightmap, color.rgb, false);

  vec3 newGAUX1Lightmap = minimumLight * 0.02 + (ambientLightmap + sunlightLightmap * shading2) * gaux3SkyLightmap + newGaux3TorchLightmap;
			 newGAUX1Lightmap = doEmissiveLight(newGAUX1Lightmap, texture2D(gaux1, texcoord.xy).rgb, true);

	color.rgb = lowlightEye(color.rgb);
  color.rgb *= newLightmap;

	if (water) {

		float waterDepth = mix(1.0 - pow(texture2D(gdepth, texcoord.st).r, 1.3), 0.0, 1.0 - gaux3SkyLightmap);

		color.rgb = mix(color.rgb * waterColor, underwaterColor * 0.15, waterDepth);

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

  gl_FragData[0] = vec4(color.rgb / maxColorRange, getVolumetricRays());
	gl_FragData[1] = vec4(newGAUX1Lightmap / maxColorRange, shading2);

}
