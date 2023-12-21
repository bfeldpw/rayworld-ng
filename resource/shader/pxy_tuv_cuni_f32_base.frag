#version 330 core

in vec2 v_uv;

uniform vec4 u_col;
uniform sampler2D u_tex;

out vec4 FragColor;

void main()
{
    FragColor = texture(u_tex, v_uv) * u_col;
}
