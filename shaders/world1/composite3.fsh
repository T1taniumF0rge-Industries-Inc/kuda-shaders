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

#define bloom
//#define anamorphicLens
//#define dirtyLens
#define fogBlur

in vec2 texcoord;

uniform sampler2D composite;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

float luma(vec3 clr) {
	return dot(clr, vec3(0.3333));
}

vec3 makeBloom(float lod, vec2 offset) {

	// By Capt Tatsu

	vec3 bloomSample = vec3(0.0);

	#if defined bloom || defined fogBlur || defined anamorphicLens || defined dirtyLens

		vec3 temp = vec3(0.0);

		float scale = pow(2.0, lod);
		vec2 coord = (texcoord.xy - offset) * scale;

		if (coord.x > -0.1 && coord.y > -0.1 && coord.x < 1.1 && coord.y < 1.1) {

			for (int i = -3; i < 4; i++) {

					for (int j = -3; j < 4; j++) {

							float wg = pow((1.0 - length(vec2(i, j)) / 4.0), 2.0) * pow(0.5, 0.5) * 20.0;
							vec2 bcoord = (texcoord.xy - offset + vec2(i, j) * pw * vec2(1.0, aspectRatio)) * scale;

					if (wg > 0){

						temp = pow(texture2D(composite, bcoord).rgb, vec3(2.2)) * wg;
						bloomSample += temp;

					}

				}

			}

			bloomSample /= 49;

		}

	#endif

	return bloomSample;

}



void main() {

	const bool compositeMipmapEnabled = true;

	vec3 blur  = vec3(0.0);
	 		 blur += makeBloom(2.0, vec2(0,0));
	 	 	 blur += makeBloom(3.0, vec2(0.3, 0.0));
	 	 	 blur += makeBloom(4.0, vec2(0.0, 0.3));
	 	 	 blur += makeBloom(5.0, vec2(0.1, 0.3));
	 	 	 blur += makeBloom(6.0, vec2(0.2, 0.3));
	 	 	 blur += makeBloom(7.0, vec2(0.3, 0.3));

			 blur = clamp(pow(blur, vec3(0.454545)), 0.0, 1.0);

/* DRAWBUFFERS:7 */

	gl_FragData[0] = vec4(blur, luma(texture2D(composite, texcoord.st).rgb));

}
