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
//#define shakingCamera

out vec4 color;
out vec4 vtexcoordam;
out vec4 vtexcoord;
out vec4 worldposition;
out vec3 viewVector;
out vec3 tangent;
out vec3 normal;
out vec3 binormal;
out vec2 texcoord;
out vec2 lmcoord;
out float translucent;
out float emissiveLight;
out float dist;

uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
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

  texcoord = gl_MultiTexCoord0.st;

  vec2 midcoord 				= (gl_TextureMatrix[0] *  mc_midTexCoord).st;
  vec2 texcoordminusmid	= texcoord - midcoord;

  lmcoord         = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
  vtexcoordam.pq  = abs(texcoordminusmid) * 2;
	vtexcoordam.st  = min(texcoord, midcoord - texcoordminusmid);
	vtexcoord.xy   	= sign(texcoordminusmid) * 0.5 + 0.5;
  color           = gl_Color;
  normal          = normalize(gl_NormalMatrix * gl_Normal);
  translucent     = 0.0;
  emissiveLight   = 0.0;
  tangent         = vec3(0.0);
	binormal        = vec3(0.0);

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

	worldposition = position + vec4(cameraPosition.xyz, 0.0);

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

	#ifdef shakingCamera
		position += vec4(0.02 * sin(frameTimeCounter * 2.0), 0.005 * cos(frameTimeCounter * 3.0), 0.0, 0.0) * gbufferModelView;
	#endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

  // Which entities should be translucent.
	if (mc_Entity.x == 6.0 ||	// Saplings
			mc_Entity.x == 18.0 ||	// Oak leaves
			mc_Entity.x == 30.0 ||	// Cobweb
			mc_Entity.x == 31.0 ||	// Grass
			mc_Entity.x == 37.0 ||	// Yellow flower
			mc_Entity.x == 38.0 ||	// Red flower and others
			mc_Entity.x == 59.0 ||	// Wheat Crops
			mc_Entity.x == 83.0 ||	// Sugar Canes
			mc_Entity.x == 106.0 ||	// Vines
			mc_Entity.x == 141.0 ||	// Carrots
			mc_Entity.x == 142.0 ||	// Potatoes
			mc_Entity.x == 161.0 ||	// Acacia leaves
			mc_Entity.x == 175.0 || // Large grass, flowers, etc.
			mc_Entity.x == 207.0 // Beetroot
			) translucent = 1.0;

	if (mc_Entity.x == 89.0 ||	// Glowstone
			mc_Entity.x == 50.0 ||	// Torch
			mc_Entity.x == 51.0 ||	// Fire
			mc_Entity.x == 91.0 ||	// Jack o'Lantern
			mc_Entity.x == 124.0 ||	// Redstone Lamp
			mc_Entity.x == 138.0 ||	// Beacon
			mc_Entity.x == 169.0 ||	// Sea Latern
			mc_Entity.x == 10.0 ||	// Lava
			mc_Entity.x == 11.0	||	// Lava
			mc_Entity.x == 198.0 // End rod
			) emissiveLight = 1.0;

	tangent			= normalize(gl_NormalMatrix * at_tangent.xyz );
	binormal		= normalize(gl_NormalMatrix * -cross(gl_Normal, at_tangent.xyz));

	dist = length(gbufferModelView * gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex);

	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
												tangent.y, binormal.y, normal.y,
												tangent.z, binormal.z, normal.z);

	viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;

}
