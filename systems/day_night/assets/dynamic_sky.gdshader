shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.3, 0.55, 0.9);
uniform vec3 sky_horizon_color : source_color = vec3(0.7, 0.85, 1.0);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;

uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.85);
uniform vec3 moon_color : source_color = vec3(0.8, 0.85, 0.9);
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);

uniform vec2 cloud_direction = vec2(1.0, 0.5);
uniform float cloud_speed = 0.03;

uniform float lightning_amount : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	// Hash estável em ponto flutuante (Dave_Hoskins style). 
	// Evita estourar o limite de decímais no longo prazo que causa o "flick/travada" nas nuvens.
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float noise(vec2 x) {
	vec2 p = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(p + vec2(0.0, 0.0));
	float b = hash(p + vec2(1.0, 0.0));
	float c = hash(p + vec2(0.0, 1.0));
	float d = hash(p + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 x) {
	float v = 0.0;
	float a = 0.5;
	vec2 shift = vec2(100.0);
	mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.50)));
	for (int i = 0; i < 5; ++i) {
		v += a * noise(x);
		x = rot * x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = max(0.0, dir.y);
	
	// Fundo em Cel-Shading (Banding - faixas de cor bem demarcadas)
	float sky_gradient = smoothstep(0.0, 0.6, up);
	sky_gradient = floor(sky_gradient * 5.0) / 4.0; 
	vec3 sky_bg = mix(sky_horizon_color, sky_top_color, sky_gradient);
	
	float sky_lum = dot(sky_top_color, vec3(0.333));
	// Fade suave: estrelas começam a surgir quando o céu atinge luminosidade 0.45 e chegam ao máximo em 0.15
	float is_night_factor = smoothstep(0.45, 0.15, sky_lum);
	
	// Estrelas
	// Arredondar posições para ficarem nítidas/cel-shaded
	vec2 grid = floor(dir.xy * 200.0) / 200.0;
	float star_hash = hash(grid * 5.0 + floor(dir.zx * 200.0) / 40.0);
	float star = step(0.985, star_hash); // corte duro (step) em vez de suave
	// Cintilar com "frames" pra manter o estilo toon
	float twinkle = floor(sin(TIME * 4.0 + star_hash * 100.0) * 3.0) / 2.0; 
	star *= clamp(twinkle, 0.2, 1.0);
	star *= step(0.05, dir.y) * is_night_factor; // cortadas do chão pra baixo
	vec3 star_color = vec3(1.0) * star;

	// Estrelas cadentes estilo toon/anime (riscos secos e brilhantes)
	float ss_time = TIME * 1.0; 
	float ss_id = floor(ss_time);
	float ss_t = fract(ss_time);
	vec2 ss_pos_start = vec2(hash(vec2(ss_id, 1.0)), hash(vec2(ss_id, 2.0))) * 1.5 - 0.75;
	vec2 ss_pos_end = ss_pos_start + vec2(0.6, -0.3); 
	float ss_mask = 0.0;
	
	if (is_night_factor > 0.5 && ss_pos_start.y > 0.0) {
		vec2 current_ss = mix(ss_pos_start, ss_pos_end, ss_t);
		// Cauda longa: o ponto final do segmento é 25% de tempo para trás
		vec2 tail_ss = mix(ss_pos_start, ss_pos_end, max(0.0, ss_t - 0.25));
		
		vec2 PA = dir.xy - tail_ss;
		vec2 BA = current_ss - tail_ss;
		// Projeção ponto a segmento
		float h = clamp(dot(PA, BA) / max(dot(BA, BA), 0.0001), 0.0, 1.0);
		float dist_to_line = length(PA - h * BA);
		
		// Afunilamento (raio maior na cabeça 'h=1.0', zero na ponta da cauda 'h=0.0')
		float trail_radius = mix(0.0, 0.006, h);
		float is_ss_trail = step(dist_to_line, trail_radius);
		
		// A cabeça ainda leva um brilho esférico sutil maior que o rastro
		float is_ss_head = step(length(dir.xy - current_ss), 0.008); 
		
		float is_ss = clamp(is_ss_head + is_ss_trail, 0.0, 1.0);
		// Fade rígido
		float ss_fade = step(0.1, sin(ss_t * 3.14159)); 
		ss_mask = is_ss * ss_fade;
	}
	star_color += vec3(1.0, 0.9, 0.5) * ss_mask * is_night_factor;

	// Sol (Cel Shaded)
	vec3 sun_dir = sun_direction;
	float sun_dist = distance(dir, sun_dir);
	float sun_disc = step(sun_dist, 0.04);
	// Glow como um anel seco em volta
	float sun_glow = step(sun_dist, 0.07) - sun_disc; 
	vec3 final_sun = sun_disc * sun_color + sun_glow * sun_color * 0.5;

	// Lua (Cel Shaded com crateras e fases de volta!)
	vec3 m_dir = moon_direction;
	float moon_dist = distance(dir, m_dir);
	float moon_disc = step(moon_dist, 0.04);
	
	// Matemática de Fases da Lua
	float phase_offset = (moon_phase * 2.0) - 1.0; 
	// Cria uma sombra que corta a lua usando um vetor distorcido
	vec3 moon_shadow_dir = normalize(m_dir + vec3(phase_offset * 0.07, 0.015, 0.0));
	float moon_shadow_dist = distance(dir, moon_shadow_dir);
	float moon_shadow_disc = step(moon_shadow_dist, 0.045);
	float moon_mask = clamp(moon_disc - moon_shadow_disc, 0.0, 1.0);
	
	// Textura de crateras rústicas
	float moon_noise = noise(floor(dir.xy * 80.0)/80.0 * 100.0);
	float crater_mask = step(0.65, moon_noise); // Hard cut para as crateras
	vec3 final_moon = moon_color * moon_mask;
	final_moon -= final_moon * crater_mask * 0.3; // Escurece crateras secamente
	
	// Glow da lua agora respeita a própria sombra da fase para não ficar um círculo oco bizarro!
	float moon_glow = step(moon_dist, 0.07) - moon_disc;
	float glow_mask = clamp(moon_glow - moon_shadow_disc, 0.0, 1.0);
	final_moon += moon_color * glow_mask * 0.5 * is_night_factor;

	// OCLUSÃO! 
	// O Sol e a Lua escondem as estrelas que estiverem atrás deles.
	float astros_block = clamp(sun_disc + moon_disc, 0.0, 1.0);
	star_color *= (1.0 - astros_block);
	
	// Mas a Lua não esconde o céu (sky_bg)! O céu deve preencher a parte escura da lua para que ela não fique preta!
	sky_bg *= (1.0 - sun_disc); 

	vec3 base_sky = sky_bg + star_color + final_sun + final_moon;

	// Raios (Relâmpagos)
	float lightning = 0.0;
	if (lightning_amount > 0.0) {
		float l_time = TIME * 2.0; // Velocidade da simulação de raios
		float l_seed = floor(l_time);
		float l_frac = fract(l_time); // 0 a 1 durante o "tick" do relâmpago
		
		// Sorteia se neste "tick" haverá um raio
		if (hash(vec2(l_seed, 7.3)) < (0.2 * lightning_amount)) {
			// Sorteia a posição (ângulo no horizonte)
			float ang = hash(vec2(l_seed, 1.1)) * 6.2831;
			vec2 l_dir = vec2(cos(ang), sin(ang));
			
			// Distância angular do pixel atual para o raio
			vec2 flat_dir = normalize(dir.xz);
			float dist = length(flat_dir - l_dir);
			
			// Distorcer o raio com ruído forte (zigue-zague)
			// Aumentamos a frequência no Y para ele ir quebrando
			float l_noise = noise(vec2(dir.y * 12.0, l_seed * 100.0)) * 0.3 - 0.15;
			// Adiciona quebras secas (fractais)
			l_noise += (noise(vec2(dir.y * 30.0, l_seed * 50.0)) * 0.1 - 0.05);
			
			float actual_dist = abs(dist + l_noise);
			
			// Tronco do raio: linha finíssima
			float l_core = step(actual_dist, 0.005 + (dir.y * 0.01)); // Levemente mais grosso em cima
			
			// Flash violento no tempo (fade out rápido no meio do tick)
			float flash = step(l_frac, 0.15) * (1.0 - (l_frac / 0.15));
			
			// Clarão de ambiente perto do raio (glow no céu)
			float ambient_flash = smoothstep(0.4, 0.0, actual_dist) * flash * 0.4;
			
			lightning = (l_core * flash) + ambient_flash;
			// Raio precisa vir do céu pra terra (não aparece "por baixo" da terra)
			lightning *= step(0.0, dir.y);
		}
	}
	
	// Soma o clarão/raio no fundo antes das nuvens (ilumina nuvem por trás) ou pode somar depois
	base_sky += vec3(0.8, 0.9, 1.0) * lightning * 2.0;

	// Nuvens Cel-Shaded (Mais baixas e acompanhando ventos)
	// Aumentando o descemos a abóboda (antes 0.35, agora 0.65 achata mais o céu)
	vec2 cloud_uv = dir.xz / (max(dir.y, 0.0) + 0.65); 
	
	// Vetor de vento arrastando as nuvens
	vec2 wind_offset = normalize(cloud_direction) * (TIME * cloud_speed);
	
	float n = fbm(cloud_uv * 1.5 + wind_offset); 
	
	// Corte duro para formar a nuvem
	float cloud_alpha = step(1.0 - cloud_coverage, n);
	// Limitar no horizonte suavemente (smoothstep) para as nuvens não surgirem cortadas do nada
	cloud_alpha *= smoothstep(0.005, 0.08, dir.y);

	// Shading Estilo Zelda BOTW (Iluminação Direcional de Nuvens)
	// Transição muito suave no crepúsculo para que a iluminação não vire instantaneamente
	float is_sun_active = smoothstep(-0.05, 0.05, sun_direction.y);
	vec3 active_light_dir = mix(moon_direction, sun_direction, is_sun_active);
	vec3 active_light_col = mix(moon_color, sun_color, is_sun_active);
	
	// Amostramos o formato da nuvem um pouco em direção à luz
	vec2 light_offset = normalize(active_light_dir.xz) * 0.02;
	float n_light = fbm(cloud_uv * 1.5 + wind_offset + light_offset);
	
	// Se a densidade (altura) for maior na direção da luz, então está iluminado. 
	// Passo 'step' garante cel-shading (corte duro entre luz e sombra).
	float cloud_light_mask = step(n, n_light);
	
	// --- MISTURA ZELDA (Iluminação Física Toon) ---
	// O quanto a chuva bloqueia o sol? (0 = dia lindo, 1 = tempestade fechada)
	float storm_density = lightning_amount; 
	
	// Borda inferior fininha da nuvem (força um traço de sombra cel-shaded)
	float cloud_border = step(n, (1.0 - cloud_coverage) + 0.015);
	// Faixa um pouco mais larga onde a luz do sol transborda (Rim Light)
	float rim_band = step(n, (1.0 - cloud_coverage) + 0.08); 
	
	// Sombra Normal (Azulada) vs Sombra de Tempestade (Chumbo / Preto Azulado)
	vec3 base_shadow = mix(cloud_color, sky_top_color, 0.5);
	vec3 storm_shadow = sky_top_color * 0.3; 
	vec3 cloud_shadow_color = mix(base_shadow, storm_shadow, storm_density);
	
	// Lado Iluminado (Brilha com a cor da luz real, ou fica cinza opaco na chuva)
	vec3 lit_sun_color = (cloud_color * 0.6) + (active_light_col * 0.8);
	vec3 cloud_lit_color = mix(lit_sun_color, storm_shadow * 1.5, storm_density);
	
	// Aplica a separação direcional de luz e sombra (Face clara vs Escura)
	vec3 final_cloud_color = mix(cloud_shadow_color, cloud_lit_color, cloud_light_mask);
	
	// Halo / Rim Light: As nuvens ficam incandescentes quando cobrem o sol/lua!
	float light_dist = distance(dir, active_light_dir);
	float halo_intensity = smoothstep(0.7, 0.1, light_dist) * (1.0 - storm_density); 
	vec3 halo_color = active_light_col * halo_intensity * 1.8;
	
	// Somamos o Halo na faixa da borda
	final_cloud_color += halo_color * rim_band;
	
	// Passamos a "caneta preta" da borda mais fina (desenho Toon)
	final_cloud_color = mix(final_cloud_color, cloud_shadow_color, cloud_border);
	
	// Os relâmpagos devem iluminar pesadamente o interior das nuvens cinzas!
	final_cloud_color += vec3(0.8, 0.9, 1.0) * lightning * cloud_alpha * 2.0;
	
	COLOR = mix(base_sky, final_cloud_color, cloud_alpha);
}
