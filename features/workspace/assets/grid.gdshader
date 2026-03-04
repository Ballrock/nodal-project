shader_type canvas_item;

uniform vec4 background_color : source_color = vec4(0.08, 0.08, 0.09, 1.0);
uniform vec4 line_color : source_color = vec4(0.12, 0.12, 0.14, 1.0);
uniform vec4 major_line_color : source_color = vec4(0.16, 0.16, 0.18, 1.0);
uniform float grid_size = 50.0;
uniform float major_grid_step = 5.0;
uniform float line_width = 1.0; // Largeur de ligne en pixels écran

float get_grid(vec2 uv, float size, float width) {
    // Calcul de la distance à la ligne la plus proche
    vec2 grid = abs(mod(uv + size * 0.5, size) - size * 0.5);
    // On utilise fwidth pour savoir combien d'unités d'UV représentent 1 pixel écran
    vec2 unit = fwidth(uv);
    // On lisse sur la largeur spécifiée
    vec2 line = smoothstep(unit * (width + 0.5), unit * (width - 0.5), grid);
    return max(line.x, line.y);
}

void fragment() {
    // On utilise les UVs qui sont déjà scalés par le zoom du parent (CanvasContent)
    // Multiplier par une grande constante permet de garder une précision flottante correcte
    vec2 uv = UV * 10000.0; 
    
    float g1 = get_grid(uv, grid_size, line_width);
    float g2 = get_grid(uv, grid_size * major_grid_step, line_width * 1.2);
    
    vec4 color = mix(background_color, line_color, g1);
    color = mix(color, major_line_color, g2);
    
    COLOR = color;
}
