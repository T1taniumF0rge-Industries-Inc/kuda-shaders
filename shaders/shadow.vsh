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

#define windyTerrain
#define windSpeed 1.0 // [0.1 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6]
#define shadowMapBias 0.8 // [0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95] A higher value means sharper shadows, but also less detail in the distance.


out vec2 texcoord;

uniform mat4 gbufferModelView;

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;


vec3 calcMove(vec3 pos, float mcID, bool isWeldedToGround, float strength, float posRes) {

	float speed = 3.0 * windSpeed;

	#ifdef windyTerrain

		bool onGround = gl_MultiTexCoord0.t < mc_midTexCoord.t;

		float movementX = sin(frameTimeCounter * speed + pos.z * posRes + cameraPosition.z * posRes);
		float movementY = sin(frameTimeCounter * speed + pos.z * posRes + cameraPosition.z * posRes);
		float movementZ = sin(frameTimeCounter * speed + pos.x * posRes + cameraPosition.x * posRes);

		float random = max(sin(frameTimeCounter * 0.2) * cos(frameTimeCounter * 0.3), 0.0);

		float windfallX = (1.0 + sin(frameTimeCounter * speed * 2.0 + pos.z * posRes + cameraPosition.z * posRes)) * 5.0 * random;
		float windfallZ = sin(frameTimeCounter * speed * 2.0 + pos.x * posRes + cameraPosition.x * posRes) * 2.0 * random;

		// Movement is based on the sky lightmap.
		strength *= (gl_TextureMatrix[1] * gl_MultiTexCoord1).t;

		if (isWeldedToGround) {

			if (mc_Entity.x == mcID && onGround) {

				pos.x += (movementX + windfallX) * strength;
				pos.z += movementZ * strength;

			}

		} else {

			if (mc_Entity.x == mcID) {

				pos.x += (movementX + windfallX) * strength;
				pos.y += movementY * strength;
				pos.z += (movementZ + windfallZ) * strength;

			}

		}

	#endif

	return pos;

}


void main() {

	gl_Position = ftransform();

  texcoord = gl_MultiTexCoord0.st;

  vec4 position = gl_Position;
       position = shadowProjectionInverse * position;
       position = shadowModelViewInverse * position;

	// Windy terrain.
	position.xyz = calcMove(position.xyz, 6.0, true, 0.01, 5.0);		// Saplings.
	position.xyz = calcMove(position.xyz, 18.0, false, 0.005, 10.0);		// Oak leaves.
	position.xyz = calcMove(position.xyz, 31.0, true, 0.03, 5.0);		// Grass.
	position.xyz = calcMove(position.xyz, 37.0, true, 0.01, 5.0);		// Yellow flower.
	position.xyz = calcMove(position.xyz, 38.0, true, 0.01, 5.0);		// Red flower and others.
	position.xyz = calcMove(position.xyz, 59.0, true, 0.02, 5.0);		// Wheat Crops.
	position.xyz = calcMove(position.xyz, 141.0, true, 0.01, 5.0);		// Carrots.
	position.xyz = calcMove(position.xyz, 142.0, true, 0.01, 5.0);		// Potatoes.
	position.xyz = calcMove(position.xyz, 161.0, false, 0.005, 10.0);	// Acacia leaves.
	position.xyz = calcMove(position.xyz, 207.0, true, 0.01, 5.0);		// Beetroot.

	position = shadowModelView * position;
	position = shadowProjection * position;

	gl_Position = position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = (1.0f - shadowMapBias) + dist * shadowMapBias;
	gl_Position.xy *= 1.0f / distortFactor;

	gl_FrontColor = gl_Color;

}
