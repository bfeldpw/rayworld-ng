#version 330 core
layout (location = 0) in vec2 pos;
layout (location = 2) in vec2 uv;

out vec2 v_uv;

uniform vec4 t; // orthogonal transformation

void main()
{
    v_uv = uv;
    gl_Position = vec4((pos.x-t.z)*t.x, (t.w-pos.y)*t.y, 0.0, 1.0);
}
