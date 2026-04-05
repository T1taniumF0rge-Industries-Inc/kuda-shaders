#version 120

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

//#define motionblur
	#define motionblurAmount 1.0 // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]

#define maxColorRange 6.0

varying vec4 color;
varying vec2 texcoord;

uniform sampler2D composite;
uniform sampler2D depthtex2;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;


vec3 doMotionblur(vec3 clr) {

	const int	motionblurSamples	= 8;

	#ifdef motionblur

		float depth = texture2D(depthtex2, texcoord.st).x;

		vec4 currentPosition = vec4(texcoord.x * 2.0 - 1.0, texcoord.y * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0);

		vec4 fragposition = gbufferProjectionInverse * currentPosition;
		fragposition = gbufferModelViewInverse * fragposition;
		fragposition /= fragposition.w;
		fragposition.xyz += cameraPosition;

		vec4 previousPosition = fragposition;
		previousPosition.xyz -= previousCameraPosition;
		previousPosition = gbufferPreviousModelView * previousPosition;
		previousPosition = gbufferPreviousProjection * previousPosition;
		previousPosition /= previousPosition.w;

		vec2 velocity = (currentPosition - previousPosition).st * motionblurAmount * 0.01;
		velocity = clamp(sqrt(dot(velocity, velocity)), 0.0, motionblurAmount * 0.01) * normalize(velocity);

		int samples = 1;

		vec2 coord = texcoord.st + velocity;

		for (int i = 0; i < motionblurSamples; ++i, coord += velocity) {

			if (coord.s > 1.0 || coord.t > 1.0 || coord.s < 0.0 || coord.t < 0.0) {
				break;
			}

			clr += texture2D(composite, coord).rgb * maxColorRange;
			++samples;

		}

		clr = clr / samples;

	#endif

	return clr;

}

void main() {

	// Get main color.
	vec3 color = texture2D(composite, texcoord.st).rgb * maxColorRange;

	color.rgb = doMotionblur(color.rgb);

/* DRAWBUFFERS:3 */

	gl_FragData[0] = vec4(color.rgb / maxColorRange, 0.0);

}
