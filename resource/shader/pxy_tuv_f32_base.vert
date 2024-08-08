#version 330 core

layout (location = 0) in vec2 pos;
layout (location = 2) in vec2 uv;

out vec2 v_uv;

uniform vec4 t; // orthogonal transformation

void main()
{
    v_uv = uv;
    gl_Position = vec4(pos.x * t.x + t.z, pos.y * t.y + t.w, 0.0, 1.0);
    // float z = 1 + 10*uv.x;
    // gl_Position = vec4((pos.x * t.x + t.z) * z, (pos.y * t.y + t.w) * z, -2 * -z - 2.0, z);
}
