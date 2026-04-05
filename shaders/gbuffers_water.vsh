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
out vec4 position2;
out vec4 worldposition;
out vec3 tangent;
out vec3 normal;
out vec3 binormal;
out vec2 texcoord;
out vec2 lmcoord;
out float water;
out float ice;
out float stainedGlass;
out float stainedGlassPlane;
out float netherPortal;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;


void main() {

  texcoord          = gl_MultiTexCoord0.st;
  lmcoord           = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
  normal            = normalize(gl_NormalMatrix * gl_Normal);
  color             = gl_Color;
  water             = 0.0;
  ice               = 0.0;
  stainedGlass      = 0.0;
  stainedGlassPlane = 0.0;
  tangent           = vec3(0.0);
	binormal          = vec3(0.0);

  position2 = gl_ModelViewMatrix * gl_Vertex;

  vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

	worldposition = position + vec4(cameraPosition.xyz, 0.0);

  #ifdef shakingCamera
		position += vec4(0.02 * sin(frameTimeCounter * 2.0), 0.005 * cos(frameTimeCounter * 3.0), 0.0, 0.0) * gbufferModelView;
	#endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

  if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) water = 1.0;
  if (mc_Entity.x == 79.0) ice = 1.0;
  if (mc_Entity.x == 90.0) netherPortal = 1.0;
  if (mc_Entity.x == 95.0) stainedGlass = 1.0;
  if (mc_Entity.x == 160.0) stainedGlassPlane = 1.0;

  tangent			= normalize(gl_NormalMatrix * at_tangent.xyz );
	binormal		= normalize(gl_NormalMatrix * -cross(gl_Normal, at_tangent.xyz));

}
