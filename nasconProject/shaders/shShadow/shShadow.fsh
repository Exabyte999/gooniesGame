// A soft dark silhouette of the sprite: its shape blurred a little, in one shadow colour.
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform vec2 u_texel;   // size of one texture pixel

void main()
{
	float a = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			a += texture2D(gm_BaseTexture, v_vTexcoord + vec2(float(i), float(j)) * u_texel).a;
		}
	}
	a /= 9.0;
	gl_FragColor = vec4(0.05, 0.08, 0.12, a * v_vColour.a);
}
