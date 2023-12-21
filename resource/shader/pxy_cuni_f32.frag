#version 330 core

uniform vec4 u_col;

out vec4 FragColor;

void main()
{
    FragColor = u_col;
}
