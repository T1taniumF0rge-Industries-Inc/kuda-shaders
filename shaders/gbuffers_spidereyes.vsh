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
out vec2 texcoord;
out vec2 lmcoord;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform float frameTimeCounter;


void main() {

  texcoord = gl_MultiTexCoord0.st;
  lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
  color    = gl_Color;

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

  #ifdef shakingCamera
		position += vec4(0.02 * sin(frameTimeCounter * 2.0), 0.005 * cos(frameTimeCounter * 3.0), 0.0, 0.0) * gbufferModelView;
	#endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

}
