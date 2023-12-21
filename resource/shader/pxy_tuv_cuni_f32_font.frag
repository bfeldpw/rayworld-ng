#version 330 core

in vec2 v_uv;

uniform vec4 u_col;
uniform sampler2D u_tex;

out vec4 FragColor;

void main()
{
    vec4 sampled = vec4(1.0, 1.0, 1.0, texture(u_tex, v_uv).r);
    FragColor = sampled * u_col;
}
