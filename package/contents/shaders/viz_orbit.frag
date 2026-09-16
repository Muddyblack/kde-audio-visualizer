#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix; float qt_Opacity;
    vec2 canvasSize; float halfCount; float innerRadius; float reach;
    float ringRotation; float timeSeconds; float style; float lineWidth;
    float fillAmount; float glowAmount; float particleCount; float colorCount;
    float failed;
    vec4 color0; vec4 color1; vec4 color2; vec4 color3; vec4 color4; vec4 color5;
    vec4 levels0;
    vec4 levels1;
    vec4 levels2;
    vec4 levels3;
    vec4 levels4;
    vec4 levels5;
    vec4 levels6;
    vec4 levels7;
    vec4 levels8;
    vec4 levels9;
    vec4 levels10;
    vec4 levels11;
    vec4 particle0;
    vec4 particle1;
    vec4 particle2;
    vec4 particle3;
    vec4 particle4;
    vec4 particle5;
    vec4 particle6;
    vec4 particle7;
    vec4 particle8;
    vec4 particle9;
    vec4 particle10;
    vec4 particle11;
    vec4 particle12;
    vec4 particle13;
    vec4 particle14;
    vec4 particle15;
    vec4 particle16;
    vec4 particle17;
    vec4 particle18;
    vec4 particle19;
    vec4 particle20;
    vec4 particle21;
    vec4 particle22;
    vec4 particle23;
    vec4 particle24;
    vec4 particle25;
    vec4 particle26;
    vec4 particle27;
    vec4 particle28;
    vec4 particle29;
    vec4 particle30;
    vec4 particle31;
};
float levelAt(int i) {
    if(i < 4) return levels0[i-0];
    if(i < 8) return levels1[i-4];
    if(i < 12) return levels2[i-8];
    if(i < 16) return levels3[i-12];
    if(i < 20) return levels4[i-16];
    if(i < 24) return levels5[i-20];
    if(i < 28) return levels6[i-24];
    if(i < 32) return levels7[i-28];
    if(i < 36) return levels8[i-32];
    if(i < 40) return levels9[i-36];
    if(i < 44) return levels10[i-40];
    if(i < 48) return levels11[i-44];
    return 0.0;
}
vec4 particleAt(int i) {
    if(i == 0) return particle0;
    if(i == 1) return particle1;
    if(i == 2) return particle2;
    if(i == 3) return particle3;
    if(i == 4) return particle4;
    if(i == 5) return particle5;
    if(i == 6) return particle6;
    if(i == 7) return particle7;
    if(i == 8) return particle8;
    if(i == 9) return particle9;
    if(i == 10) return particle10;
    if(i == 11) return particle11;
    if(i == 12) return particle12;
    if(i == 13) return particle13;
    if(i == 14) return particle14;
    if(i == 15) return particle15;
    if(i == 16) return particle16;
    if(i == 17) return particle17;
    if(i == 18) return particle18;
    if(i == 19) return particle19;
    if(i == 20) return particle20;
    if(i == 21) return particle21;
    if(i == 22) return particle22;
    if(i == 23) return particle23;
    if(i == 24) return particle24;
    if(i == 25) return particle25;
    if(i == 26) return particle26;
    if(i == 27) return particle27;
    if(i == 28) return particle28;
    if(i == 29) return particle29;
    if(i == 30) return particle30;
    if(i == 31) return particle31;
    return vec4(0.0);
}
const float TAU=6.28318530718;
float value(int j) {
    int n=int(halfCount)*2;
    j=(j%n+n)%n;
    return levelAt(j<int(halfCount)?j:n-1-j);
}
float angle(int j) {return float(j)/(halfCount*2.0)*TAU+ringRotation-TAU*.25;}
vec2 polar(float r,float a) {return vec2(cos(a),sin(a))*r;}
float segment(vec2 p,vec2 a,vec2 b) {
    vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/max(dot(d,d),.0001),0.0,1.0));
}
float coverage(float d) {return 1.0-smoothstep(-.65,.65,d);}
vec4 stopAt(int i) {
    if(i==0)return color0;if(i==1)return color1;if(i==2)return color2;
    if(i==3)return color3;if(i==4)return color4;return color5;
}
vec4 ink(vec2 p) {
    if(colorCount<1.5)return color0;
    float turn=mod(atan(p.y,p.x)-ringRotation+TAU*.25,TAU)/TAU;
    float f=turn*colorCount;int j=int(floor(f));
    return mix(stopAt(j),stopAt((j+1)%int(colorCount)),fract(f));
}
vec4 over(vec4 a,vec4 b) {return a+b*(1.0-a.a);}
vec4 stroke(vec4 color,float d,float alpha) {
    float core=coverage(d)*alpha;
    float glow=exp(-pow(max(0.0,d)/3.5,2.0))*.28*glowAmount*alpha;
    return over(color*core,color0*glow);
}
vec2 point(int j,float scale) {return polar(innerRadius+2.0+value(j)*reach*scale,angle(j));}
float curveDistance(vec2 p,int bin,float scale) {
    float d=10000.0;
    for(int k=-2;k<=2;k++) {
        int j=bin+k;vec2 b=point(j,scale);
        vec2 a=(point(j-1,scale)+b)*.5,c=(b+point(j+1,scale))*.5,prev=a;
        for(int s=1;s<=8;s++) {
            float t=float(s)/8.0;
            vec2 q=(1.0-t)*(1.0-t)*a+2.0*t*(1.0-t)*b+t*t*c;
            d=min(d,segment(p,prev,q));prev=q;
        }
    }
    return d;
}
float cross2(vec2 a,vec2 b) {return a.x*b.y-a.y*b.x;}
float curveRadius(vec2 direction,int bin) {
    float radius=10000.0;
    for(int k=-2;k<=2;k++) {
        int j=bin+k;vec2 middle=point(j,1.0);
        vec2 left=(point(j-1,1.0)+middle)*.5,right=(middle+point(j+1,1.0))*.5;
        vec2 A=left-2.0*middle+right,B=2.0*(middle-left),C=left;
        float a=cross2(A,direction),b=cross2(B,direction),c=cross2(C,direction);
        float discriminant=b*b-4.0*a*c;
        if(abs(a)<.00001) {
            if(abs(b)>.00001) {
                float t=-c/b;
                if(t>=0.0 && t<=1.0) {float r=dot(A*t*t+B*t+C,direction);if(r>0.0)radius=min(radius,r);}
            }
        } else if(discriminant>=0.0) {
            for(int signIndex=0;signIndex<2;signIndex++) {
                float t=(-b+(signIndex==0?-1.0:1.0)*sqrt(discriminant))/(2.0*a);
                if(t>=0.0 && t<=1.0) {float r=dot(A*t*t+B*t+C,direction);if(r>0.0)radius=min(radius,r);}
            }
        }
    }
    return radius<9999.0?radius:innerRadius;
}
vec2 ribbonPoint(int j,int layer) {
    float a=angle(j),t=timeSeconds*(1.2+float(layer)*.4)+float(layer)*2.0;
    return polar(innerRadius+3.0+value(j)*reach*(.55+.45*sin(a*3.0+t)),a);
}
void main() {
    if(failed>.5){fragColor=vec4(0.0);return;}
    vec2 p=(qt_TexCoord0-.5)*canvasSize;float r=length(p);
    float a=mod(atan(p.y,p.x)-ringRotation+TAU*.25,TAU);
    int bin=int(floor(a/TAU*halfCount*2.0+.5));
    vec4 color=ink(p);
    vec4 result=color*(.18*coverage(abs(r-innerRadius)-.5));
    if(style<.5) {
        float d=10000.0;
        for(int k=-3;k<=3;k++) {
            int j=bin+k;float ang=angle(j);
            d=min(d,segment(p,polar(innerRadius+3.0,ang),polar(innerRadius+5.0+value(j)*reach,ang)));
        }
        float w=max(1.4,min(TAU*innerRadius/(halfCount*2.0)*.55,lineWidth*1.6));
        result=over(stroke(color,d-w*.5,1.0),result);
    } else if(style<1.5) {
        float d=curveDistance(p,bin,1.0);
        if(fillAmount>.5) {
            float boundary=curveRadius(r>.0001?p/r:vec2(1.0,0.0),bin);
            result=over(color*(.22*coverage(r-boundary)),result);
        }
        result=over(stroke(color,d-lineWidth*.5,1.0),result);
        result=over(stroke(color,curveDistance(p,bin,.5)-.5,.45),result);
    } else if(style<2.5) {
        float d=10000.0,rad=1.1*max(.8,lineWidth/1.8);
        for(int k=-3;k<=3;k++) {
            int j=bin+k;float extent=value(j)*reach,ang=angle(j);
            float q=clamp(floor((r-innerRadius-3.0)/5.0+.5),0.0,max(0.0,ceil(extent/5.0)-1.0))*5.0;
            if(extent>0.0)d=min(d,length(p-polar(innerRadius+3.0+q,ang))-rad);
            d=min(d,length(p-polar(innerRadius+3.0+extent,ang))-rad*1.6);
        }
        result=over(color*coverage(d),result);
    } else if(style<3.5) {
        vec4 ribbons=vec4(0.0);
        for(int layer=0;layer<3;layer++) {
            float d=10000.0;
            for(int k=-2;k<=2;k++) {int j=bin+k;d=min(d,segment(p,ribbonPoint(j,layer),ribbonPoint(j+1,layer)));}
            ribbons+=stroke(color,d-(layer==0?1.0:.5),layer==0?.9:layer==1?.5:.3);
        }
        result=over(min(ribbons,vec4(1.0)),result);
    } else {
        for(int i=0;i<32;i++) {
            if(float(i)>=particleCount)break;
            vec4 spark=particleAt(i);
            result=over(stroke(color,length(p-spark.xy)-spark.z,spark.w),result);
        }
    }
    fragColor=result*qt_Opacity;
}
