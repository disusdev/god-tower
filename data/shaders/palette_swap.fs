// palette_swap.fs
#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 palette[256]; // Assuming a maximum of 256 colors in the palette

out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);

    // Indexing based on grayscale value
    float gray = dot(texelColor.rgb, vec3(0.299, 0.587, 0.114));
    int index = int(gray * 255.0); // Convert grayscale to an index (0-255)

    finalColor = palette[index]; // Lookup the color in the palette
}