#version 330 core
layout (location = 0) in vec2 pos;
layout (location = 1) in vec4 col;

out vec4 v_col;

uniform vec4 t; // orthogonal transformation

void main()
{
    v_col = col;
    gl_Position = vec4(pos.x * t.x + t.z, pos.y * t.y + t.w, 0.0, 1.0);
}
