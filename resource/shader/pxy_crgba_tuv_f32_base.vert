#version 330 core
layout (location = 0) in vec2 pos;
layout (location = 1) in vec4 col;
layout (location = 2) in vec2 uv;

out vec4 v_col;
out vec2 v_uv;

uniform vec4 t; // orthogonal transformation

void main()
{
    v_col = col;
    v_uv = uv;
    gl_Position = vec4((pos.x-t.z)*t.x, (-pos.y+t.w)*t.y, 0.0, 1.0);
}
