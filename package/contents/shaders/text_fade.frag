#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix; float qt_Opacity; float fadeFraction;
};
layout(binding=1) uniform sampler2D source;
void main() {
    float mask=smoothstep(0.0,fadeFraction,qt_TexCoord0.x)
        *smoothstep(0.0,fadeFraction,1.0-qt_TexCoord0.x);
    fragColor=texture(source,qt_TexCoord0)*mask*qt_Opacity;
}
