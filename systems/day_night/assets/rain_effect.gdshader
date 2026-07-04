shader_type canvas_item;

uniform float rain_amount : hint_range(0.0, 1.0) = 1.0;
uniform float fall_speed : hint_range(0.0, 10.0) = 2.0;
uniform float slant : hint_range(-1.0, 1.0) = 0.2;
uniform vec4 rain_color : source_color = vec4(0.8, 0.9, 1.0, 0.5);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	if (rain_amount <= 0.0) {
		discard;
	}

	// Coord inclinada baseada no slant
	vec2 uv = SCREEN_UV;
	uv.x += uv.y * slant;
	
	// Criar camadas (grids independentes caindo)
	float rain_mask = 0.0;
	
	for (float i = 1.0; i <= 3.0; i += 1.0) {
		// Diferentes escalas de grid para paralaxe 2D (alguns finos, outros grossos)
		vec2 grid_uv = uv * vec2(60.0 * i, 4.0 * i); 
		// Animando a queda no Y
		grid_uv.y -= TIME * fall_speed * (1.0 + i * 0.5);
		
		vec2 id = floor(grid_uv);
		vec2 local = fract(grid_uv);
		
		// Random chance de ter pingo nesse tile
		float h = hash(id);
		
		// Desenho rígido do pingo (cel shading lines)
		if (h < 0.12 * rain_amount) {
			// Linha fina no X, esticada no Y
			float drop = step(abs(local.x - 0.5), 0.05);
			// Corte suave nas pontas do risco para não parecer blocão
			drop *= smoothstep(0.0, 0.2, local.y) * smoothstep(1.0, 0.8, local.y);
			// fade aleatorio
			drop *= mix(0.4, 1.0, hash(id + 1.0));
			rain_mask = max(rain_mask, drop);
		}
	}
	
	COLOR = rain_color;
	COLOR.a *= rain_mask * rain_amount;
}
