#version 330 core
layout (location = 0) in vec2 pos;

uniform vec4 t; // orthogonal transformation

void main()
{
    gl_Position = vec4(pos.x * t.x + t.z, pos.y * t.y + t.w, 0.0, 1.0);
}
