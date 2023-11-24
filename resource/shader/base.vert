#version 400 core
layout (location = 0) in vec2 pos;
layout (location = 1) in uint col;

out vec4 v_col;

uniform vec4 t; // orthogonal transformation

void main()
{
    v_col = unpackUnorm4x8(col);
    gl_Position = vec4((pos.x-t.z)*t.x, (-pos.y+t.w)*t.y, 0.0, 1.0);
}
