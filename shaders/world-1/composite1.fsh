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

#define reflections
#define waterShader
#define waterRefraction
#define windSpeed 1.0 // [0.1 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6]

#define maxColorRange 6.0

in vec4 color;
in vec3 lightVector;
in vec2 texcoord;

in vec3 skyColor;
in vec3 fogColor;
in vec3 underwaterColor;

uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D gdepth;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 previousCameraPosition;

uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;

uniform float near;
uniform float far;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float wetness;
uniform float viewWidth;
uniform float viewHeight;

uniform int worldTime;
uniform int isEyeInWater;

vec3  normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
vec3  gaux2normal = texture2D(gaux2, texcoord.st).rgb * 2.0 - 1.0;
float depth0 = texture2D(depthtex0, texcoord.st).x;
float depth1 = texture2D(depthtex1, texcoord.st).x;
float skyLightmap = clamp(pow(texture2D(gdepth, texcoord.st).r, 2.0), 0.0, 1.0);
float shading2 = texture2D(gcolor, texcoord.st).a;

float gaux3SkyLightmap = clamp(pow(texture2D(gaux3, texcoord.st).r, 2.0), 0.0, 1.0);
float gaux3Material = texture2D(gaux3, texcoord.st).b;

float	comp = 1.0 - near / far / far;

bool land	= depth1 < comp;
bool sky	= depth1 > comp;

bool water = gaux3Material > 0.09 && gaux3Material < 0.11;
bool ice = gaux3Material > 0.19 && gaux3Material < 0.21;
bool stainedGlass = gaux3Material > 0.29 && gaux3Material < 0.31;
bool hand = gaux3Material > 0.49 && gaux3Material < 0.51;
bool GAUX1 = gaux3Material > 0.0;		// Ask for all materials which are stored in gaux3 for gaux1.

bool reflectiveBlocks = water || ice || stainedGlass;

float globalLightmap = reflectiveBlocks || hand? gaux3SkyLightmap : skyLightmap;

// r = default reflection
// g = wetness reflection
// b = rain puddles
// a = wetness map
vec4 specular = texture2D(gaux4, texcoord.st);

float linearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float readDepth(in vec2 coord) {
	return (2.0 * near) / (far + near - texture2D(depthtex0, coord).x * (far - near));
}

float cdist(vec2 coord) {
	return max(abs(coord.s - 0.5), abs(coord.t - 0.5)) * 2.0;
}

vec3 nvec3(vec4 pos) {
    return pos.xyz / pos.w;
}

float autoExpsoure() {

	float exposureAmount = 2.5;

	float aE_lightmap	= 1.0 - pow(eyeBrightnessSmooth.y / 240.0, 1.0);

	return 1.0 + aE_lightmap * exposureAmount;

}

vec3 drawSky(vec3 fragpos, bool forReflections) {

	return skyColor;

}

vec3 drawFog(vec3 clr, vec3 fragpos) {

	float fogStartDistance		= 125.0;	// Higher -> far.
	float fogDensity 					= 1.0;

	// Make the fog stronger while raining.
	fogDensity = mix(fogDensity, min(fogDensity * 1.5, 1.0), rainStrength);

	float fogFactor = 1.0 - exp(-pow(length(fragpos.xyz) / max(fogStartDistance, 0.0), 2.0));

	// Remove fog when player is underwater.
	if (bool(isEyeInWater)) fogFactor = 0.0;

	clr = mix(clr.rgb, fogColor, fogFactor * fogDensity);

	return clr;

}

vec3 drawUnderwaterFog(vec3 clr, vec3 fragpos) {

	float fogStartDistance	= 15.0;	// Higher -> far.
	float fogDensity 				= 1.0;
	float minimumBrightness = 0.4;

	vec4 worldPos = gbufferModelViewInverse * vec4(fragpos, 1.0);

	float fogFactor = 1.0 - exp(-pow(length(fragpos.xyz) / fogStartDistance, 2.0));
		  	fogFactor = mix(0.0, fogFactor, fogDensity);

	if (bool(isEyeInWater)) clr = mix(clr.rgb * vec3(0.6, 0.8, 1.0), underwaterColor * 0.15 * max(eyeBrightnessSmooth.y / 240.0f, minimumBrightness), fogFactor);

	return clr;

}

vec4 raytrace(vec3 fragpos, vec3 rVector) {

	// By Chocapic13

	int maxf = 6;				//number of refinements
	float stp = 1.0;			//size of one step for raytracing algorithm
	float ref = 0.07;			//refinement multiplier
	float inc = 2.2;			//increasement factor at each step

  vec4 color = vec4(0.0);

	#ifdef reflections

		vec3 start = fragpos;
		vec3 vector = stp * rVector;

		fragpos += vector;
		vec3 tvector = vector;

		int sr = 0;

		for (int i = 0; i < 28; i++) {

			vec3 pos = nvec3(gbufferProjection * vec4(fragpos, 1.0)) * 0.5 + 0.5;
			if (pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;

				vec3 spos = vec3(pos.st, texture2DLod(depthtex1, pos.st, 0.0).r);
						 spos = nvec3(gbufferProjectionInverse * vec4(spos * 2.0 - 1.0, 1.0));

				float err = distance(fragpos.xyz, spos.xyz);

				if (err < (reflectiveBlocks? pow(length(vector) * 1.5, 1.15) : pow(length(vector) * pow(length(tvector), 0.11), 1.1) * 1.1)) {

					sr++;

					if (sr >= maxf) {

						bool rLand = texture2DLod(depthtex1, pos.st, 0.0).x < comp;

						float border = clamp(1.0 - pow(cdist(pos.st), 10.0), 0.0, 1.0);

            if (rLand) {

						  color = vec4(texture2DLod(composite, pos.st, 0.0).rgb, 1.0);
              color.rgb *= maxColorRange;

              color.rgb = drawFog(color.rgb, fragpos.xyz);

            }

						color.a *= border;

						break;

					}

				tvector -= vector;
				vector *= ref;

			}

			vector *= inc;
			tvector += vector;
			fragpos = start + tvector;

		}

	#endif

  return color;

}

vec3 getReflection(vec3 clr, vec3 fragpos0, vec3 fragpos1, vec3 skyFragpos) {

	float reflectionStrength = 1.0;

	vec3 getNormal = normal;
	if (reflectiveBlocks || hand) getNormal = gaux2normal;

	vec3 reflectedVector0 = reflect(normalize(fragpos0.xyz), getNormal);
	vec3 reflectedVector1 = reflect(normalize(fragpos1.xyz), getNormal);
	vec3 reflectedSkyVector = reflect(normalize(skyFragpos.xyz), getNormal) * 500.0;

	if (!reflectiveBlocks) reflectionStrength *= mix(0.0, 1.0, min(pow(specular.r, 2.2), 1.0));

  #ifndef reflections
		if (reflectiveBlocks) reflectionStrength *= 0.5;
	#endif

  // Make relfective blocks not fully relfective.
	if (texture2D(gaux1, texcoord.xy).a > 0.6 && stainedGlass) reflectionStrength = 0.0;

	float normalDotEye = dot(getNormal, normalize(fragpos1.xyz));
	float fresnel	= pow(1.0 + normalDotEye, 2.0);

  vec3 reflectedSky = drawSky(reflectedSkyVector.xyz, false);

	vec4 reflection = raytrace(fragpos1.xyz, reflectedVector1);
		   reflection.rgb = mix(reflectedSky, reflection.rgb, reflection.a);

	clr.rgb = mix(clr.rgb, reflection.rgb, fresnel * reflectionStrength);

	return clr;

}

float waterWaves(vec3 worldPos) {

	float wave = 0.0;

	#if defined waterShader && defined waterRefraction

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

		wave = wave * 0.167;

	#endif

	return wave;

}


vec3 getRefraction(vec3 clr, vec3 fragpos) {

	float	waterRefractionStrength = 0.08;
	float rgbOffset = 0.007;
	float blurFactor = 0.0;		// Mipmapping

	vec4 worldPos = gbufferModelViewInverse * vec4(fragpos, 1.0);

	vec2 waterTexcoord = texcoord.st;

	waterRefractionStrength *= mix(0.2, 1.0, exp(-pow(length(fragpos.xyz) / 25.0, 1.5)));
	rgbOffset *= waterRefractionStrength;

	#ifdef waterRefraction

		float deltaPos = 0.1;
		float h0 = waterWaves(worldPos.xyz + cameraPosition.xyz);
		float h1 = waterWaves(worldPos.xyz + cameraPosition.xyz - vec3(deltaPos, 0.0, 0.0));
		float h2 = waterWaves(worldPos.xyz + cameraPosition.xyz - vec3(0.0, 0.0, deltaPos));

		float dX = ((h0-h1))/deltaPos;
		float dY = ((h0-h2))/deltaPos;

		vec3 waterRefract = normalize(vec3(dX, dY, 1.0));
		float refMult = sqrt(1.0 - pow(dot(gaux2normal, normalize(fragpos).xyz), 2.0)) * waterRefractionStrength;

		waterTexcoord = texcoord.st + waterRefract.xy * refMult;

		float mask = texture2D(gaux3, waterTexcoord.st).b;
		bool watermask = mask > 0.09 && mask < 0.1 || mask > 0.19 && mask < 0.21;

		waterTexcoord.st = watermask? waterTexcoord.st : texcoord.st;

		float underwaterSkyLightmap = 1.0 - clamp(pow(texture2D(gdepth, waterTexcoord.st).r, 2.0), 0.0, 1.0);

		vec3 watercolor   = vec3(0.0);
				 watercolor.r = texture2DLod(composite, waterTexcoord.st + rgbOffset, underwaterSkyLightmap * blurFactor).r;
				 watercolor.g = texture2DLod(composite, waterTexcoord.st, underwaterSkyLightmap * blurFactor).g;
				 watercolor.b = texture2DLod(composite, waterTexcoord.st - rgbOffset, underwaterSkyLightmap * blurFactor).b;

	 	float depthInWater1 = texture2D(depthtex1, waterTexcoord.st).x;

	 	bool skyInWater	= depthInWater1 > comp;

		clr = skyInWater? clr : water || ice? watercolor * maxColorRange : clr;

	#endif

	return clr;

}

vec3 drawGAUX1(vec3 clr) {

	vec4 aColor = texture2D(gaux1, texcoord.xy) * vec4(texture2D(gcolor, texcoord.st).rgb, 1.0);

	aColor.rgb *= maxColorRange;

	// Water shouldn't been redrawn.
	#ifdef waterShader
		if (water) aColor = vec4(clr.rgb, 1.0);
	#endif

	return mix(clr, aColor.rgb, aColor.a) + aColor.rgb * (1.0 - aColor.a);

}

void main() {

	const bool compositeMipmapEnabled = true;

	// Get main color.
	vec3 color = texture2D(composite, texcoord.st).rgb * maxColorRange;

	vec4 fragposition0  = gbufferProjectionInverse * (vec4(texcoord.st, depth0, 1.0) * 2.0 - 1.0);
       fragposition0 /= fragposition0.w;

	vec4 fragposition1  = gbufferProjectionInverse * (vec4(texcoord.st, depth1, 1.0) * 2.0 - 1.0);
	     fragposition1 /= fragposition1.w;

	vec4 skyFragposition  = gbufferProjectionInverse * (vec4(texcoord.st, 1.0, 1.0) * 2.0 - 1.0);
	     skyFragposition /= skyFragposition.w;




	if (sky) color.rgb = drawSky(skyFragposition.xyz, false);
	color.rgb = getRefraction(color.rgb, fragposition0.xyz);
	if (!water) color.rgb = drawFog(color.rgb, fragposition1.xyz);
	color.rgb = drawGAUX1(color.rgb);
  if (GAUX1 && !hand) color.rgb = drawFog(color.rgb, fragposition0.xyz);
	color.rgb = getReflection(color.rgb, fragposition1.xyz, fragposition0.xyz, skyFragposition.xyz);
	color.rgb = drawUnderwaterFog(color.rgb, fragposition0.xyz);
	color.rgb = color.rgb * autoExpsoure();

/* DRAWBUFFERS:3 */

	gl_FragData[0] = vec4(color.rgb / maxColorRange, 0.0);

}
