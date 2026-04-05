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

out vec3 lightVector;
out vec2 texcoord;

out vec3 underwaterColor;
out vec3 torchColor;
out vec3 waterColor;
out vec3 lowlightColor;

uniform sampler2D noisetex;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform float rainStrength;
uniform float frameTimeCounter;

uniform int worldTime;


void main() {

  texcoord = gl_MultiTexCoord0.st;

	gl_Position = ftransform();

  if (float(worldTime) < 12700 || float(worldTime) > 23250) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}

  underwaterColor = vec3(0.0, 0.65, 1.0) * 0.1;

	torchColor = vec3(1.0, 0.57, 0.3);

  waterColor = vec3(0.7, 0.85, 1.0);

	lowlightColor = vec3(0.65, 0.8, 1.0);

}
