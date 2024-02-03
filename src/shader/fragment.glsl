#version 330 core
out vec4 FragColor;

in vec3 out_normal;

void main()
{
    FragColor = vec4(1.0f + out_normal.x, 0.5f + out_normal.y, 0.2f + out_normal.z, 1.0f);
} 