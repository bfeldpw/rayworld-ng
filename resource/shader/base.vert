#version 330 core
layout (location = 0) in vec2 pos;

uniform vec4 t; // orthogonal transformation

void main()
{
    gl_Position = vec4((pos.x-t.z)*t.x, (-pos.y+t.w)*t.y, 0.0, 1.0);
}
