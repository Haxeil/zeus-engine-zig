#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec3 normal;
layout (location = 3) in vec4 color;
 
out vec3 out_normal;

uniform vec3 _offset;
uniform mat4 _p;
uniform mat4 _v;


void main()
{
    vec3 p = aPos + _offset;
    gl_Position = _p * _v * vec4(p.x, p.y, p.z, 1.0);
    out_normal = normal;
}