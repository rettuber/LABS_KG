#define PI 3.14159265359

float key(int k){ return texelFetch(iChannel1, ivec2(k,0), 0).x; }

vec3 rotX(vec3 p, float a){ float c=cos(a), s=sin(a); return vec3(p.x, c*p.y - s*p.z, s*p.y + c*p.z); }
vec3 rotY(vec3 p, float a){ float c=cos(a), s=sin(a); return vec3(c*p.x + s*p.z, p.y, -s*p.x + c*p.z); }

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    ivec2 fc = ivec2(fragCoord);
    if(fc.y!=0 || fc.x>1){ fragColor = vec4(0); return; }

    if(iFrame==0)
    {
        if(fc.x==0) fragColor = vec4(0.0, 0.15, -1.0, -1.0);
        else        fragColor = vec4(0.0, 0.15, 0.0,  0.0);
        return;
    }

    vec4 s0 = texelFetch(iChannel0, ivec2(0,0), 0);
    vec4 s1 = texelFetch(iChannel0, ivec2(1,0), 0);

    float yaw   = s0.x;
    float pitch = s0.y;
    float shotT = s0.z;
    float explT = s0.w;

    float shotYaw   = s1.x;
    float shotPitch = s1.y;
    float prevSpace = s1.z;

    float L = max(key(65), key(37)); 
    float R = max(key(68), key(39)); 
    float U = max(key(87), key(38)); 
    float Dn= max(key(83), key(40)); 
    float sp= key(32);

    float dt = iTimeDelta;

    yaw   += (R-L) * dt * 1.8;
    yaw    = atan(sin(yaw), cos(yaw));

    pitch += (U-Dn) * dt * 1.2;
    pitch  = clamp(pitch, -0.15, 0.65);

    
    float cooldown = 0.55;
    if(sp>0.5 && prevSpace<0.5 && (iTime-shotT) > cooldown)
    {
        shotT     = iTime;
        shotYaw   = yaw;
        shotPitch = pitch;
        explT     = -1.0;
    }

    if(shotT>0.0 && explT<0.0)
    {
        float t = iTime - shotT;
        if(t>0.0)
        {
            vec3 turret = vec3(0.0, 0.65, 0.10);
            vec3 dir    = rotY( rotX(vec3(0,0,1), -shotPitch), shotYaw );
            vec3 muzzle = turret + dir*1.35;

            float spd = 10.5;
            float g   = 3.0;
            vec3 pos  = muzzle + dir*spd*t + vec3(0.0, -0.5*g*t*t, 0.0);

            vec3 enemy = vec3(0.0, 0.45, 6.0);
            if(length(pos-enemy) < 1.05) { explT = iTime; shotT = -1.0; }

            if(pos.y < 0.0 || t > 6.0) shotT = -1.0;
        }
    }

    if(fc.x==0) fragColor = vec4(yaw, pitch, shotT, explT);
    else        fragColor = vec4(shotYaw, shotPitch, sp, 0.0);
}