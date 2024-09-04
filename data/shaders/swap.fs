#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform sampler2D palette;
uniform vec2 texelSize;
uniform float paletteIndex;
uniform int colorDiv;

vec2 corners[4] = vec2[4](
    vec2(0.0, 0.0),
    vec2(0.9, 0.0),
    vec2(0.0, 0.9),
    vec2(0.9, 0.9)
);

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    float index = texelColor.r * colorDiv;
    
    vec2 paletteCoord;
    paletteCoord.x = paletteIndex * texelSize.x;
    paletteCoord.y = index * texelSize.y;
    
    vec4 c_color = vec4(0);
    for (int i = 0; i < 4; i++) {
        vec2 c_coord = paletteCoord;
        c_coord.x = c_coord.x + corners[i].x * texelSize.x;
        c_coord.y = c_coord.y + corners[i].y * texelSize.y;
        c_color = c_color + texture(palette, c_coord);
    }
    c_color = c_color / 4.0;
    
    c_color.a = texelColor.a;
    finalColor = c_color;
}