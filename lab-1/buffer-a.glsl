const int KEY_LEFT  = 37;
const int KEY_RIGHT = 39;

vec4 loadState(int x)
{
    return texelFetch(iChannel0, ivec2(x, 0), 0);
}

float keyDown(int key)
{
    return texelFetch(iChannel1, ivec2(key, 0), 0).x;
}

float laneX(float r01)
{
    float lane = floor(r01 * 3.0); 
    return (lane - 1.0) * LANE_SPACING;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    ivec2 fc = ivec2(fragCoord);

    if (fc.y != 0)
    {
        fragColor = vec4(0.0);
        return;
    }

    if (fc.x == 0)
    {
        vec4 car = loadState(0);

        if (iFrame == 0)
        {
            car = vec4(0.0, 0.0, iTime, 0.0);
            fragColor = car;
            return;
        }

        float prevT = car.z;
        float dt = clamp(iTime - prevT, 0.0, 0.05);
        prevT = iTime;

        float L = keyDown(KEY_LEFT);
        float R = keyDown(KEY_RIGHT);

        float a = (R - L) * 6.0;

        car.y += a * dt;
        car.y *= exp(-8.0 * dt);
        car.x += car.y * dt;

        car.x = clamp(car.x, -ROAD_HALF_W + CAR_MARGIN, ROAD_HALF_W - CAR_MARGIN);
        car.z = prevT;

        fragColor = car;
        return;
    }

    if (fc.x >= 1 && fc.x <= NUM_OBS)
    {
        int id = fc.x - 1;

        float prevT = loadState(0).z;
        float dt = (iFrame == 0) ? 0.0 : clamp(iTime - prevT, 0.0, 0.05);

        vec4 o = loadState(fc.x);

        if (iFrame == 0)
        {
            float seed = hash11(float(id) * 17.13 + 1.0);

            float rLane = hash11(seed + 2.0);
            float rY    = hash11(seed + 3.0);
            float rWait = hash11(seed + 4.0);

            o.x = laneX(rLane);

            o.w = rWait * 0.6;
            if (o.w > 0.05) o.y = -2.0;
            else           o.y = mix(-0.2, TOP_SPAWN, rY);

            o.z = seed;
            fragColor = o;
            return;
        }

        float sp = gameSpeed(iTime) * (0.85 + 0.35 * hash11(o.z + 9.0));

        if (o.w > 0.0)
        {
            o.w = max(0.0, o.w - dt);
            o.y = -2.0;

            if (o.w <= 0.0)
                o.y = TOP_SPAWN;
        }
        else
        {
            o.y -= sp * dt;

            if (o.y < BOTTOM_KILL)
            {
                float seed = o.z;

                float rDelay = hash11(seed + 10.0);
                float rLane  = hash11(seed + 20.0);

                o.x = laneX(rLane);
                o.w = mix(0.15, 0.75, rDelay);
                o.y = -2.0;

                o.z = hash11(seed + 1.234 + float(id) * 7.77);
            }
        }

        fragColor = o;
        return;
    }

    fragColor = vec4(0.0);
}
