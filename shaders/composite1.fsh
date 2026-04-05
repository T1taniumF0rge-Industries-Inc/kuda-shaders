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
#define rainPuddles
#define waterShader
#define waterRefraction
#define clouds
#define stars
#define airDensity 1.0 // [0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0]
#define windSpeed 1.0 // [0.1 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6]
//#define dynamicWeather
//#define useFixedWeatherRatio
#define volumetricLight
	#define vlQuality 0.75 // [0.3 0.5 0.75 1.0 1.5 2.0]
	#define vlRaysStrength 0.5 // [0.5 0.6 0.7 0.8 0.9 1.0]

#define maxColorRange 6.0

in vec4 color;
in vec3 lightVector;
in vec2 texcoord;
in float weatherRatio;

in vec3 rayColor;
in vec3 sunColor;
in vec3 moonColor;
in vec3 skyColor;
in vec3 horizonColor;
in vec3 fogColor;
in vec3 underwaterColor;
in vec3 cloudColor;

in float TimeSunrise;
in float TimeNoon;
in float TimeSunset;
in float TimeMidnight;
in float TimeDay;
in float DayToNightFading;

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
uniform sampler2D noisetex;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;

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
float material = texture2D(gdepth, texcoord.st).b;

float gaux3SkyLightmap = clamp(pow(texture2D(gaux3, texcoord.st).r, 2.0), 0.0, 1.0);
float gaux3Material = texture2D(gaux3, texcoord.st).b;



// Booleans..
float	comp = 1.0 - near / far / far;

bool land	= depth1 < comp;
bool sky	= depth1 > comp;

bool raindrops = gaux3Material > 0.69 && gaux3Material < 0.71;
bool water = gaux3Material > 0.09 && gaux3Material < 0.11;
bool ice = gaux3Material > 0.19 && gaux3Material < 0.21;
bool stainedGlass = gaux3Material > 0.29 && gaux3Material < 0.31;
bool hand = gaux3Material > 0.49 && gaux3Material < 0.51;
bool GAUX1 = gaux3Material > 0.0;		// Ask for all materials which are stored in gaux3 for gaux1.

bool reflectiveBlocks = water || ice || stainedGlass;



// Common variables..
float globalLightmap = reflectiveBlocks || hand? gaux3SkyLightmap : skyLightmap;

// r = default reflection
// g = wetness reflection
// b = rain puddles
// a = wetness map
vec4 specular = texture2D(gaux4, texcoord.st);

float ambInfluence = 1.0 / airDensity;
float eyeAdapt = eyeBrightnessSmooth.y / 240.0;



// User defined functions..
float linearDepth(float depth){
	return 2.0 * (near * far) / (far + near - (depth) * (far - near));
}

float cdist(vec2 coord) {
	return max(abs(coord.s - 0.5), abs(coord.t - 0.5)) * 2.0;
}

vec3 cameraSpaceToScreenSpace(vec3 fragpos) {

	vec4 pos  = gbufferProjection * vec4(fragpos, 1.0);
			 pos /= pos.w;

	return pos.xyz * 0.5 + 0.5;

}

vec3 cameraSpaceToWorldSpace(vec3 fragpos) {

	vec4 pos  = gbufferProjectionInverse * vec4(fragpos, 1.0);
			 pos /= pos.w;

	return pos.xyz;

}

float luma(vec3 clr) {
	return dot(clr, vec3(0.3333));
}

float rand(vec2 co) {

    float a = 12.9898;
    float b = 78.233;
    float c = 43758.5453;
		float pi = 3.14159265359;

    float dt= dot(co.xy, vec2(a, b));
    float sn= mod(dt, pi);

    return fract(sin(sn) * c);
}

float autoExpsoure() {

	const float exposureAmount = 1.5;

	float aE_lightmap	= 1.0 - eyeAdapt;
				aE_lightmap = mix(aE_lightmap, 1.0, pow(TimeMidnight, 2.5));

	return 1.0 + aE_lightmap * exposureAmount;

}

float getWorldHorizonPos(vec3 fragpos) {

	float position		= dot(normalize(fragpos.xyz), upPosition);
	float horizonPos	= mix(clamp(1.0 - pow(abs(position) / 15.0, 0.7), 0.0, 1.0), 1.0, 1.0 - clamp(position + length(position), 0.0, 1.0));

	return horizonPos;

}

vec3 drawSky(vec3 fragpos) {

	// Get position.
	float position = dot(normalize(fragpos.xyz), upPosition);
	float sunVector = max(dot(normalize(fragpos), normalize(sunPosition)), 0.0);

	float sun	= pow(sunVector, 5.0);

	float horizonPos 	= pow(max(1.0 - pow(abs(position) * 0.02 * ambInfluence, 0.6), 0.0), 1.3);
	float skyPos		= max(1.0 - abs(position) * 0.00625 * ambInfluence * 0.8, 0.0);

	vec3 skyColor = mix(skyColor * skyPos, horizonColor, horizonPos);
		 	 skyColor = mix(skyColor, skyColor * 0.5, getWorldHorizonPos(fragpos.xyz) * 0.4);

	return skyColor;

}

vec3 drawStars(vec3 clr, vec3 fragpos) {

	#ifdef stars

		const float starsScale = 0.05;
		const float starsMovementSpeed = 0.001;

		vec4 worldPos = gbufferModelViewInverse * vec4(fragpos.xyz, 1.0);

		float position = dot(normalize(fragpos.xyz), upPosition);
		float horizonPos = max(1.0 - pow(abs(position) * 0.013, 1.0), 0.0);

		vec2 coord = (worldPos.xz / (worldPos.y / pow(position, 0.75)) * starsScale) + vec2(frameTimeCounter * starsMovementSpeed);

		float noise  = texture2D(noisetex, coord).x;
					noise += texture2D(noisetex, coord * 2.0).x / 2.0;
					noise += texture2D(noisetex, coord * 6.0).x / 6.0;

		noise = max(noise - 1.4, 0.0);
		noise = mix(noise, 0.0, clamp(getWorldHorizonPos(fragpos) + horizonPos, 0.0, 1.0));

		clr = mix(clr, vec3(2.5), noise * TimeMidnight * (1.0 - weatherRatio));

	#endif

	return clr;

}

vec3 drawSun(vec3 clr, vec3 fragpos, bool forReflections) {

	const float sunStrength = 10.0;
	const float moonStrength = 0.8;

	// Get position.
	float sunVector = max(dot(normalize(fragpos), normalize(sunPosition)), 0.0);
	float moonVector = max(dot(normalize(fragpos), normalize(moonPosition)), 0.0);
	float moonVector2 = max(dot(normalize(fragpos), normalize(vec3(moonPosition.x + 3.0, moonPosition.y + 1.0, moonPosition.z + 0.5))), 0.0);

	// Calculate light vectors.
	float sun	= pow(sunVector, 2000.0) * sunStrength;
	float moon = clamp(pow(moonVector, 4000.0) * 10.0, 0.0, 1.0) * moonStrength;
	float moon2 = clamp(pow(moonVector2, 500.0) * 1.5, 0.0, 1.0);

	sun	 = mix(sun, 0.0, getWorldHorizonPos(fragpos.xyz));
	moon = mix(moon, 0.0, getWorldHorizonPos(fragpos.xyz));
	moon = mix(moon, 0.0, moon2);

	if (forReflections)	{
		sun  *= min(shading2 * 3.0, 1.0);
		moon *= min(shading2 * 3.0, 1.0);
	}

	clr = mix(clr, sunColor, sun * (1.0 - weatherRatio));
	clr = mix(clr, moonColor, moon * (1.0 - weatherRatio));

	return clr;

}

vec3 draw2DClouds(vec3 clr, vec3 fragpos) {

	const float cloudWindSpeed = 0.03;
	const float distortionStrength = 3.0;

	float cloudCover = 0.6;
	float cloudOpacity = 2.0;
	float sunStrength = 2.5;
	float moonStrength = 0.2;
	float shadingStrength = 0.15;

	#ifdef clouds

		// Get position.
		vec4 worldPos = gbufferModelViewInverse * vec4(fragpos, 1.0);
		vec4 worldPos2 = gbufferModelViewInverse * vec4(fragpos + lightVector * 25.0, 1.0);

		float position = dot(normalize(fragpos.xyz), upPosition);
		float horizonPos = max(1.0 - abs(position) * 0.02, 0.0);

		float sunVector = max(dot(normalize(fragpos), normalize(sunPosition)), 0.0);
		float moonVector = max(dot(normalize(fragpos), normalize(moonPosition)), 0.0);

		float curvedPos = pow(position, 0.5);


		// Calculate light vectors.
		float sun	= pow(sunVector, 5.0);
		float moon	= pow(moonVector, 10.0);

		vec2 wind = vec2(frameTimeCounter * 0.008) * cloudWindSpeed * windSpeed;

		// Apply distortion.
		worldPos.x += sin((worldPos.z / worldPos.y) * curvedPos * 0.75) * 2.5 * distortionStrength;
		worldPos.z += cos((worldPos.x / worldPos.y) * curvedPos * 1.5) * 1.25 * distortionStrength;

		mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));

		vec2 coord  = ((worldPos.xz / worldPos.y) * curvedPos * 0.0025) * rot + wind * 1.5;
		vec2 coord2  = ((worldPos2.xz / worldPos2.y) * curvedPos * 0.0025) * rot + wind * 1.5;

		float noise  = texture2D(noisetex, coord - wind).x;
					noise += texture2D(noisetex, coord * 4.0 - wind).x / 4.0;
					noise += texture2D(noisetex, coord * 12.0 - wind).x / 12.0;
					noise += texture2D(noisetex, coord * 34.0 - wind).x / 34.0;

		float noise2  = texture2D(noisetex, coord2 - wind).x;
					noise2 += texture2D(noisetex, coord2 * 4.0 - wind).x / 4.0;
					noise2 += texture2D(noisetex, coord2 * 12.0 - wind).x / 12.0;

		cloudCover = mix(cloudCover, 0.0, sqrt(weatherRatio));

		#if defined dynamicWeather || defined useFixedWeatherRatio
			cloudCover = mix(1.0, 0.0, sqrt(weatherRatio));
		#endif

		float cloud = max(noise - cloudCover * 1.2, 0.0);
					cloud *= 1.0 - min(getWorldHorizonPos(fragpos) + horizonPos, 1.0);

		float cloudShading = max(noise2 - cloudCover * 1.1, 0.0);
					//cloudShading *= 1.0 - min(getWorldHorizonPos(fragpos) + horizonPos, 1.0);

		// Apply conditions.
		sunStrength *= mix(1.0, 0.08, TimeMidnight);
		sunStrength *= mix(1.0, 0.1, weatherRatio);
		moonStrength *= mix(1.0, 0.25, TimeDay);
		moonStrength *= mix(1.0, 0.0, weatherRatio);
		shadingStrength *= mix(1.0, 0.7, weatherRatio);

		cloudOpacity = mix(cloudOpacity, cloudOpacity * 2.5, cloudCover);

		vec3 cloudClr = cloudColor;
				 cloudClr = mix(cloudClr, sunColor, sun * sunStrength * cloud);
				 cloudClr = mix(cloudClr, moonColor, moon * moonStrength * cloud);

				 // Shading..
				 cloudClr = mix(cloudClr, vec3(0.0), cloudShading * shadingStrength * cloudOpacity);

		clr = mix(clr, cloudClr, min(cloud * cloudOpacity, 1.0));

	#endif

	return clr;

}

float getVolumetricRays(vec3 fragpos) {

	vec3 pos = cameraSpaceToScreenSpace(fragpos);

	float vlMipmapping = 1.0 / vlQuality;

	float vlRays  = texture2DLod(composite, pos.st, vlMipmapping <= 1.34? 0.0 : vlMipmapping * 1.1).a;	// If the VL quality is greater than 1.0, enable mipmap.
				vlRays *= DayToNightFading * (1.0 - weatherRatio);

	return vlRays;

}

vec3 drawFog(vec3 clr, vec3 fragpos, bool forReflections) {

	const float fogDistance	= 0.004;	// Higher -> near.
	const float lightScatteringAmount	= 0.7;
	float fogDensity = 1.0;

	// Apply conditions.
	fogDensity *= airDensity;
	fogDensity *= mix(1.0, 2.0, rainStrength);
	fogDensity *= mix(1.0, 2.0, TimeMidnight);

	vec3 pos = cameraSpaceToScreenSpace(fragpos);

	float vlRays = getVolumetricRays(fragpos);

	if (bool(isEyeInWater) && !water) vlRays = 0.0;

	//if (!water) vlRays *= 1.0 - texture2D(gaux1, pos.xy).a;

	float fogFactor = 1.0 - exp(-pow(length(fragpos.xyz) * fogDistance, 1.5));

	// Remove fog when player is underwater.
	if (bool(isEyeInWater)) fogFactor = 0.0;

	fogFactor *= eyeAdapt;

	// Do atmospheric scattering.
	float lightVec = max(dot(normalize(fragpos), normalize(lightVector)), 0.0);
	float lightFactor	= pow(lightVec, 7.5) * lightScatteringAmount * mix(mix(0.5, 0.0, TimeMidnight), 1.0, vlRays);

	float infl = mix(airDensity, 1.0, TimeMidnight);

	// Air density influence.
	vec3 nFogColor = pow(fogColor, vec3(1.0 / infl)) / pow(infl, 0.4);
	vec3 nRayClr = pow(rayColor, vec3(ambInfluence));

	vec3 fogClr = mix(nFogColor, nRayClr, lightFactor * TimeDay * (1.0 - weatherRatio));
			 fogClr = mix(fogClr, nRayClr, lightFactor * 0.1 * TimeMidnight * (1.0 - weatherRatio));

	bool fLand = land;
	if (forReflections) fLand = texture2D(depthtex1, pos.xy).x < comp;

	float minFogDensity = 0.6;

	#ifndef volumetricLight
		minFogDensity = 1.0;
	#endif

	// Apply volumetric light
	fogFactor = fogFactor * minFogDensity * fogDensity + mix(vlRays * vlRaysStrength * 0.2, vlRays * vlRaysStrength, (1.0 - eyeAdapt) * TimeDay) * fogDensity;
	fogFactor = mix(0.0, fogFactor, mix(float(fLand), 1.0 - TimeMidnight * 0.5, lightFactor));

	clr = mix(clr.rgb, fogClr, min(fogFactor, 1.0));

	return clr;

}

vec3 drawUnderwaterFog(vec3 clr, vec3 fragpos) {

	const float fogDistance	= 0.067;	// Higher -> far.
	const float fogDensity = 1.0;
	const float minimumBrightness = 0.4;

	vec4 worldPos = gbufferModelViewInverse * vec4(fragpos, 1.0);

	float fogFactor = 1.0 - exp(-pow(length(fragpos.xyz) * fogDistance, 2.0));
		  	fogFactor = mix(0.0, fogFactor, fogDensity);

	if (bool(isEyeInWater)) clr = mix(clr.rgb * vec3(0.6, 0.8, 1.0), underwaterColor * 0.15 * max(eyeAdapt, minimumBrightness), fogFactor);

	return clr;

}

vec4 raytrace(vec3 reflectedSky, vec3 fragpos, vec3 rVector) {

	// By Chocapic13

	const int maxf = 6;				//number of refinements
	const float stp = 1.0;			//size of one step for raytracing algorithm
	const float ref = 0.07;			//refinement multiplier
	const float inc = 2.2;			//increasement factor at each step

  vec4 color = vec4(0.0);

	#ifdef reflections

		vec3 start = fragpos;
		vec3 vector = stp * rVector;

		fragpos += vector;
		vec3 tvector = vector;

		int sr = 0;


		for (int i = 0; i < 28; i++) {

			vec3 pos = cameraSpaceToScreenSpace(fragpos);
			if (pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;

				vec3 spos = vec3(pos.st, texture2DLod(depthtex1, pos.st, 0.0).r);
						 spos = cameraSpaceToWorldSpace(spos * 2.0 - 1.0);

				float err = distance(fragpos.xyz, spos.xyz);

				if (err < (reflectiveBlocks? pow(length(vector) * 1.5, 1.15) : pow(length(vector) * pow(length(tvector), 0.11), 1.1) * 1.1)) {

					sr++;

					if (sr >= maxf) {

						bool rLand = texture2DLod(depthtex1, pos.st, 0.0).x < comp;

						float border = clamp(1.0 - pow(cdist(pos.st), 10.0), 0.0, 1.0);

						color = vec4(texture2DLod(composite, pos.st, 0.0).rgb, 1.0);
						color.rgb *= maxColorRange;

						color.rgb = drawFog(color.rgb, fragpos.xyz, true);

						if (!rLand) color.rgb = reflectedSky;

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

	if (!reflectiveBlocks) reflectionStrength *= mix(0.0, 1.0, mix(pow(specular.r, 2.2), 0.0, specular.b) + specular.g * specular.a * specular.b);

	// Make relfective blocks not fully relfective.
	if (texture2D(gaux1, texcoord.xy).a > 0.6 && stainedGlass) reflectionStrength = 0.0;

	#ifndef reflections
		if (reflectiveBlocks) reflectionStrength *= 0.5;
	#endif

	vec3 reflectedSky	= drawSky(reflectedSkyVector.xyz);
			 reflectedSky = drawSun(reflectedSky, reflectedSkyVector.xyz, true);
			 //reflectedSky = drawStars(reflectedSky.rgb, reflectedSkyVector.xyz, true);
			 reflectedSky = draw2DClouds(reflectedSky.rgb, reflectedSkyVector.xyz);


	float normalDotEye = dot(getNormal, normalize(fragpos1.xyz));
	float fresnel	= pow(1.0 + normalDotEye, 2.0);
				fresnel = mix(fresnel, 1.0, luma(drawSun(vec3(0.0), reflectedSkyVector.xyz, true)));

	vec4 reflection = raytrace(reflectedSky, fragpos1.xyz, reflectedVector1);
		   reflection.rgb = mix(reflectedSky * globalLightmap, reflection.rgb, reflection.a);

	clr.rgb = mix(clr.rgb, reflection.rgb, min(fresnel, 1.0) * reflectionStrength);

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

	vec4 worldPos = gbufferModelViewInverse * vec4(fragpos, 1.0);

	vec2 waterTexcoord = texcoord.st;

	waterRefractionStrength *= mix(0.2, 1.0, exp(-pow(length(fragpos.xyz) * 0.04, 1.5)));
	rgbOffset *= waterRefractionStrength;

	#ifdef waterRefraction

		float deltaPos = 0.1;
		float h0 = waterWaves(worldPos.xyz + cameraPosition.xyz);
		float h1 = waterWaves(worldPos.xyz + cameraPosition.xyz - vec3(deltaPos, 0.0, 0.0));
		float h2 = waterWaves(worldPos.xyz + cameraPosition.xyz - vec3(0.0, 0.0, deltaPos));

		float dX = (h0 - h1) / deltaPos;
		float dY = (h0 - h2) / deltaPos;

		vec3 waterRefract = normalize(vec3(dX, dY, 1.0));
		float refMult = sqrt(1.0 - pow(dot(gaux2normal, normalize(fragpos).xyz), 2.0)) * waterRefractionStrength;

		waterTexcoord = texcoord.st + waterRefract.xy * refMult;

		float mask = texture2D(gaux3, waterTexcoord.st).b;
		bool watermask = mask > 0.09 && mask < 0.1 || mask > 0.19 && mask < 0.21;

		waterTexcoord.st = watermask? waterTexcoord.st : texcoord.st;

		vec3 watercolor   = vec3(0.0);
				 watercolor.r = texture2DLod(composite, waterTexcoord.st + rgbOffset, 0.0).r;
				 watercolor.g = texture2DLod(composite, waterTexcoord.st, 0.0).g;
				 watercolor.b = texture2DLod(composite, waterTexcoord.st - rgbOffset, 0.0).b;

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


	if (sky) color.rgb = drawSky(skyFragposition.xyz);
	if (sky) color.rgb = drawStars(color.rgb, skyFragposition.xyz);
	if (sky) color.rgb = drawSun(color.rgb, skyFragposition.xyz, false);
	if (sky) color.rgb = draw2DClouds(color.rgb, skyFragposition.xyz);
	if (land) color.rgb *= 1.0 - specular.a * 0.3 * wetness;
	color.rgb = getRefraction(color.rgb, fragposition0.xyz);
	if (!water) color.rgb = drawFog(color.rgb, fragposition1.xyz, false);
	color.rgb = drawGAUX1(color.rgb);
	if (GAUX1 && !hand && !raindrops) color.rgb = drawFog(color.rgb, fragposition0.xyz, false);
	color.rgb = getReflection(color.rgb, fragposition1.xyz, fragposition0.xyz, skyFragposition.xyz);
	color.rgb = drawUnderwaterFog(color.rgb, fragposition0.xyz);
	color.rgb = color.rgb * autoExpsoure();

/* DRAWBUFFERS:3 */

	gl_FragData[0] = vec4(color.rgb / maxColorRange, 1.0);

}
