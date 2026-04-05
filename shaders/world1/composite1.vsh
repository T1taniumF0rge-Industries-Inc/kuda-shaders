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
out float weatherRatio;

out vec3 skyColor;
out vec3 fogColor;
out vec3 underwaterColor;

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

	skyColor = vec3(0.8, 0.75, 1.0) * 0.1;

	fogColor = skyColor;

	underwaterColor = vec3(0.0, 0.65, 1.0);

}
