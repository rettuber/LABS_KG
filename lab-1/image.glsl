vec4 loadStateImg(int x)
{
    return texelFetch(iChannel0, ivec2(x, 0), 0);
}

float fillMask(float d, float aa)
{
    return smoothstep(aa, -aa, d);
}

float outlineMask(float d, float aa)
{
    return 1.0 - smoothstep(aa, aa * 2.0, abs(d));
}

vec3 obstacleColor(float type, float seed)
{
    float v = 0.75 + 0.35 * hash11(seed + 0.7);

    if (type < 0.5)  return vec3(0.85, 0.55, 0.15) * v; 
    if (type < 1.5)  return vec3(0.25, 0.55, 0.95) * v;
    if (type < 2.5)  return vec3(0.90, 0.90, 0.90) * v;
    return vec3(0.95, 0.85, 0.20) * v;
}

void addTrees(inout vec3 col, vec2 uv, float roadMask, float aa, float scroll)
{
    float grassMask = 1.0 - roadMask;
    if (grassMask <= 0.0) return;

    float cellH = 0.34;
    float yW = uv.y + scroll;
    float k0 = floor(yW / cellH);

    float canopyM = 0.0;
    float trunkM  = 0.0;
    float shadowM = 0.0;

    for (int j = -1; j <= 1; j++)
    {
        float k = k0 + float(j);

        for (int s = 0; s < 2; s++)
        {
            float side = (s == 0) ? -1.0 : 1.0;

            float rSpawn = hash11(k * 19.91 + side * 3.17);
            if (rSpawn > 0.32) continue;

            float ry = hash11(k * 7.13  + side * 9.71);
            float rx = hash11(k * 11.03 + side * 5.77);
            float sz = mix(0.85, 1.25, hash11(k * 2.90 + side * 6.30));

            float yC = (k + ry) * cellH - scroll;
            float xC = side * (ROAD_HALF_W + 0.16 + 0.10 * rx);

            vec2 p = (uv - vec2(xC, yC)) / sz;
            float aap = aa / sz;

            float dTr = sdRoundBox(p - vec2(0.0, 0.060), vec2(0.012, 0.060), 0.004);
            
            float dC1 = sdCircle(p - vec2(0.0, 0.145), 0.070);
            float dC2 = sdCircle(p - vec2(0.045, 0.120), 0.060);
            float dC3 = sdCircle(p - vec2(-0.045, 0.120), 0.060);
            float dC4 = sdCircle(p - vec2(0.0, 0.105), 0.055);
            float dCan = min(min(dC1, dC4), min(dC2, dC3));

            vec2 q = p - vec2(0.0, 0.015);
            float dSh = length(vec2(q.x * 1.9, q.y * 4.2)) - 0.070;

            canopyM = max(canopyM, fillMask(dCan, aap * 2.2));
            trunkM  = max(trunkM,  fillMask(dTr,  aap * 2.2));
            shadowM = max(shadowM, fillMask(dSh,  aap * 3.0));
        }
    }

    canopyM *= grassMask;
    trunkM  *= grassMask;
    shadowM *= grassMask;

    col = mix(col, col * 0.72, shadowM * 0.35);

    vec3 trunkCol  = vec3(0.33, 0.20, 0.10);
    vec3 canopyCol = vec3(0.06, 0.28, 0.07);

    col = mix(col, trunkCol,  trunkM);
    col = mix(col, canopyCol, canopyM);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float aa = 1.0 / iResolution.y;

    vec4 carS = loadStateImg(0);
    float carX = carS.x;

    float sp = gameSpeed(iTime);
    float scroll = iTime * sp * 0.95;

    vec3 col = vec3(0.10, 0.34, 0.12);
    col *= 0.92 + 0.08 * sin(uv.x * 9.0 + (uv.y + scroll) * 6.0);

    float roadEdgeD = abs(uv.x) - ROAD_HALF_W;
    float roadMask  = fillMask(roadEdgeD, aa);

    addTrees(col, uv, roadMask, aa, scroll);

    vec3 roadCol = vec3(0.07, 0.07, 0.08);
    col = mix(col, roadCol, roadMask);

    float edge = outlineMask(roadEdgeD, aa * 2.0) * roadMask;
    col += edge * vec3(0.13, 0.13, 0.13);

    float lineX = abs(abs(uv.x) - 0.5 * LANE_SPACING);
    float lineW = 0.007;
    float line = 1.0 - smoothstep(lineW, lineW + aa * 2.0, lineX);

    float t = uv.y + scroll * 0.9;
    float dash = step(0.0, sin(t * 40.0)); 

    float lane = line * dash * roadMask;
    col = mix(col, vec3(0.88), lane * 0.85);

    for (int i = 0; i < NUM_OBS; i++)
    {
        vec4 o = loadStateImg(i + 1);
        if (o.w > 0.0) continue;

        vec2 pos = vec2(o.x, o.y);
        vec2 p = uv - pos;

        float seed = o.z;
        float type = floor(hash11(seed + 5.0) * 4.0); 

        vec3 oc = obstacleColor(type, seed);

        float dShBase = sdObstacle(p + vec2(0.01, -0.015), type);
        float sh  = fillMask(dShBase + 0.010, aa * 2.0) * 0.25 * roadMask;
        col = mix(col, col * 0.75, sh);

        float d = 1e5;

        float mW = 0.0, mWin = 0.0, mStripe = 0.0;

        if (type > 2.5)
        {
            float s = 0.85;
            float dOut, dWh, dWin, dH, dT, dS;
            carSDF(p / s, dOut, dWh, dWin, dH, dT, dS);

            dOut *= s; dWh *= s; dWin *= s; dS *= s;

            d = dOut;

            float m = fillMask(d, aa * 1.5);
            mW     = fillMask(dWh,   aa * 1.5) * m;
            mWin   = fillMask(dWin,  aa * 1.5) * m;
            mStripe= fillMask(dS,    aa * 1.5) * m;

            col = mix(col, oc, m);

            col = mix(col, vec3(0.03), mW);

            col = mix(col, vec3(0.18, 0.28, 0.32), mWin * 0.95);

            col = mix(col, vec3(0.90), mStripe * 0.35);

            float ol = outlineMask(d, aa * 2.0);
            col = mix(col, vec3(0.0), ol * 0.20);

            continue;
        }
        else
        {
            d = sdObstacle(p, type);
        }

        float m = fillMask(d, aa * 1.5);
        float ol = outlineMask(d, aa * 2.0);

        col = mix(col, oc, m);
        col = mix(col, vec3(0.0), ol * 0.25);
    }

    vec2 carPos = vec2(carX, CAR_Y);
    vec2 cp = uv - carPos;

    float dOut, dWh, dWin, dH, dT, dS;
    carSDF(cp, dOut, dWh, dWin, dH, dT, dS);

    float dCarSh = sdCar(cp + vec2(0.012, -0.018));
    float carSh = fillMask(dCarSh + 0.012, aa * 2.5) * 0.30 * roadMask;
    col = mix(col, col * 0.78, carSh);

    float carM   = fillMask(dOut, aa * 1.5);
    float carOL  = outlineMask(dOut, aa * 2.0);

    vec3 paint = vec3(0.92, 0.12, 0.16);
    float shade = 0.82 + 0.18 * smoothstep(-0.11, 0.12, cp.y);
    shade *= 0.92 + 0.08 * smoothstep(0.09, 0.0, abs(cp.x));
    vec3 paintCol = paint * shade;

    col = mix(col, paintCol, carM);

    float wheelM = fillMask(dWh, aa * 1.5) * carM;
    col = mix(col, vec3(0.02, 0.02, 0.02), wheelM);

    float winM = fillMask(dWin, aa * 1.5) * carM;
    vec3 winCol = vec3(0.18, 0.32, 0.40);
    float glare = smoothstep(0.02, 0.10, cp.y) * smoothstep(0.07, 0.0, abs(cp.x));
    winCol += glare * 0.12;
    col = mix(col, winCol, winM);

    float stripeM = fillMask(dS, aa * 1.5) * carM;
    col = mix(col, vec3(0.92), stripeM * 0.55);

    float headM = fillMask(dH, aa * 1.5) * carM;
    float tailM = fillMask(dT, aa * 1.5) * carM;
    col = mix(col, vec3(1.0, 0.97, 0.80), headM);
    col = mix(col, vec3(0.95, 0.12, 0.10), tailM);

    float rim = smoothstep(0.018, 0.0, abs(dOut)) * carM;
    col += rim * 0.06;

    col = mix(col, vec3(0.0), carOL * 0.32);

    fragColor = vec4(col, 1.0);
}
