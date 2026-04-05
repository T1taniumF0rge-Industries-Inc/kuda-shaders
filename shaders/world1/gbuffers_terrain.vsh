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
  emissiveLight   = 0.0;
  tangent         = vec3(0.0);
	binormal        = vec3(0.0);

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

	worldposition = position + vec4(cameraPosition.xyz, 0.0);

	#ifdef shakingCamera
		position += vec4(0.02 * sin(frameTimeCounter * 2.0), 0.005 * cos(frameTimeCounter * 3.0), 0.0, 0.0) * gbufferModelView;
	#endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

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
