#define PI 3.14159265359
#define MAX_STEPS 96
#define MAX_DIST  45.0
#define SURF_DIST 0.0015

float gYaw, gPitch, gShotT, gExplT, gShotYaw, gShotPitch;

vec3 rotX(vec3 p, float a){ float c=cos(a), s=sin(a); return vec3(p.x, c*p.y - s*p.z, s*p.y + c*p.z); }
vec3 rotY(vec3 p, float a){ float c=cos(a), s=sin(a); return vec3(c*p.x + s*p.z, p.y, -s*p.x + c*p.z); }

float sdBox(vec3 p, vec3 b){
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x, max(q.y,q.z)), 0.0);
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r){
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa,ba)/dot(ba,ba), 0.0, 1.0);
    return length(pa - ba*h) - r;
}

float terrainH(vec2 xz){
    return 0.04*sin(0.60*xz.x)
         + 0.035*sin(0.55*xz.y)
         + 0.015*sin(1.40*xz.x + 1.20*xz.y);
}

float sdTank(vec3 p, float yaw, float pitch)
{
    float d = sdBox(p - vec3(0.0, 0.28, 0.00), vec3(0.95, 0.28, 1.25));
    d = min(d, sdBox(p - vec3(0.0, 0.15, 0.00), vec3(1.12, 0.15, 1.35)));

    vec3 tc = vec3(0.0, 0.65, 0.10);
    vec3 tp = p - tc;

    vec3 ty = rotY(tp, -yaw);
    d = min(d, sdBox(ty, vec3(0.48, 0.18, 0.55)));

    vec3 tb = rotX(ty, pitch);
    d = min(d, sdCapsule(tb, vec3(0,0,0.15), vec3(0,0,1.75), 0.07));

    return d;
}

vec3 shotPos()
{
    float t = iTime - gShotT;
    vec3 turret = vec3(0.0, 0.65, 0.10);
    vec3 dir    = rotY( rotX(vec3(0,0,1), -gShotPitch), gShotYaw );
    vec3 muzzle = turret + dir*1.35;

    float spd = 10.5;
    float g   = 3.0;
    return muzzle + dir*spd*t + vec3(0.0, -0.5*g*t*t, 0.0);
}

vec2 opU(vec2 a, vec2 b){ return (a.x < b.x) ? a : b; }

vec2 map(vec3 p)
{
    vec2 res = vec2(1e5, 0.0);

    float h = terrainH(p.xz);
    res = vec2(p.y - h, 1.0);

    res = opU(res, vec2(sdTank(p, gYaw, gPitch), 2.0));

    vec3 ep = p - vec3(0.0, 0.0, 6.0);
    ep = rotY(ep, PI);
    res = opU(res, vec2(sdTank(ep, 0.0, 0.15), 3.0));

    if(gShotT > 0.0)
    {
        float t = iTime - gShotT;
        if(t > 0.0 && t < 6.0)
        {
            vec3 sp = shotPos();
            res = opU(res, vec2(length(p-sp) - 0.09, 4.0));
        }
    }

    return res;
}

vec3 calcNormal(vec3 p){
    vec2 e = vec2(0.0015, 0.0);
    return normalize(vec3(
        map(p + e.xyy).x - map(p - e.xyy).x,
        map(p + e.yxy).x - map(p - e.yxy).x,
        map(p + e.yyx).x - map(p - e.yyx).x
    ));
}

float softShadow(vec3 ro, vec3 rd){
    float res = 1.0;
    float t = 0.02;
    for(int i=0;i<28;i++){
        float h = map(ro + rd*t).x;
        res = min(res, 10.0*h/t);
        t += clamp(h, 0.03, 0.25);
        if(res < 0.001 || t > 20.0) break;
    }
    return clamp(res, 0.0, 1.0);
}

vec2 rayMarch(vec3 ro, vec3 rd){
    float t = 0.0;
    float m = 0.0;
    for(int i=0;i<MAX_STEPS;i++){
        vec2 h = map(ro + rd*t);
        if(h.x < SURF_DIST || t > MAX_DIST){ m = h.y; break; }
        t += h.x * 0.85;
    }
    if(t > MAX_DIST) m = 0.0;
    return vec2(t, m);
}

mat3 setCam(vec3 ro, vec3 ta){
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    return mat3(uu, vv, ww);
}

vec3 albedo(float m, vec3 p)
{
    if(m < 1.5)
    {
        float g = 0.5 + 0.5*sin(0.7*p.x)*sin(0.7*p.z);
        return mix(vec3(0.16,0.20,0.12), vec3(0.24,0.22,0.14), g);
    }
    if(m < 2.5)
    {
        float c = 0.5 + 0.5*sin(6.0*p.x + 2.0*sin(3.0*p.z));
        return mix(vec3(0.18,0.28,0.18), vec3(0.25,0.35,0.22), c);
    }
    if(m < 3.5)
    {
        float c = 0.5 + 0.5*sin(5.0*p.z + 1.7*sin(3.0*p.x));
        return mix(vec3(0.28,0.26,0.20), vec3(0.38,0.34,0.26), c);
    }
    return vec3(1.00, 0.85, 0.25);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec4 s0 = texelFetch(iChannel0, ivec2(0,0), 0);
    vec4 s1 = texelFetch(iChannel0, ivec2(1,0), 0);

    gYaw   = s0.x;
    gPitch = s0.y;
    gShotT = s0.z;
    gExplT = s0.w;

    gShotYaw   = s1.x;
    gShotPitch = s1.y;

    vec2 uv = (fragCoord - 0.5*iResolution.xy) / iResolution.y;

    if(gExplT > 0.0){
        float te = iTime - gExplT;
        float sh = exp(-8.0*te) * step(te, 0.6);
        uv += sh * 0.004 * vec2(sin(70.0*iTime), cos(63.0*iTime));
    }

    vec3 ro = vec3(0.0, 2.2, -5.7);
    vec3 ta = vec3(0.0, 0.55, 3.0);
    mat3 ca = setCam(ro, ta);
    vec3 rd = ca * normalize(vec3(uv, 1.75));

    float sun = max(dot(rd, normalize(vec3(0.45,0.75,0.25))), 0.0);
    vec3 sky  = mix(vec3(0.55,0.70,0.95), vec3(0.20,0.35,0.70), clamp(1.0-rd.y,0.0,1.0));
    sky += 0.35*pow(sun, 32.0);

    vec2 tm = rayMarch(ro, rd);
    float t = tm.x;
    float m = tm.y;

    vec3 col = sky;

    if(m > 0.5)
    {
        vec3 p = ro + rd*t;
        vec3 n = calcNormal(p);

        vec3 ldir = normalize(vec3(0.45, 0.85, 0.25));
        float dif = max(dot(n, ldir), 0.0);
        float sha = softShadow(p + n*0.01, ldir);
        dif *= sha;

        float amb = 0.25 + 0.35*clamp(n.y, 0.0, 1.0);
        float spe = pow(max(dot(reflect(-ldir, n), -rd), 0.0), 48.0) * sha;

        vec3 alb = albedo(m, p);

        if(m > 1.5 && m < 3.5 && p.y < 0.23) alb *= 0.45;

        if(m > 3.5) {
            col = alb * (0.25 + 0.9*dif) + 1.2*alb;
        } else {
            col = alb * (amb + 0.95*dif) + spe*vec3(1.0);
        }

    float fog = exp(-0.03*t); 
    col = mix(sky, col, fog);
    }

    if(gExplT > 0.0)
    {
        float te = iTime - gExplT;
        if(te < 1.4)
        {
            vec3 c  = vec3(0.0, 0.45, 6.0);
            float r = 1.2 + te*2.2;

            vec3 oc = ro - c;
            float b = dot(oc, rd);
            float h = dot(oc, oc) - b*b;

            float glow = exp(-h * 2.2) * exp(-2.2*te);
            glow *= smoothstep(r*r, 0.0, h);

            col += glow * vec3(1.2, 0.55, 0.15);
        }
    }

    col = pow(max(col, 0.0), vec3(0.4545));
    fragColor = vec4(col, 1.0);
}