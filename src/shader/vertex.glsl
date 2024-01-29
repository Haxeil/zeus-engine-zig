#version 330 core
layout (location = 0) in vec3 aPos;

uniform vec3 _offset;
uniform mat4 _p;


void main()
{
    //gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    vec3 p = aPos + _offset;
    
    gl_Position = _p * vec4(p.x, p.y, p.z, 1.0);
}