#version 330 core

in vec4 v_col;
in vec2 v_uv;
in vec2 v_hc;

uniform float u_center;
uniform sampler2D tex_wall;

out vec4 FragColor;

void main()
{
    float d_y = 2.0*abs(gl_FragCoord.y + v_hc.y - u_center)/v_hc.x;
    float attenuation = 1.0 - 0.7 * pow(d_y, 40.0);
    FragColor = texture(tex_wall, v_uv) * v_col * attenuation;
}
