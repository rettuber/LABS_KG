#define NUM_OBS 6

const float ROAD_HALF_W  = 0.28;
const float LANE_SPACING = 0.18;

const float TOP_SPAWN    = 0.65;
const float BOTTOM_KILL  = -0.65;

const float CAR_Y        = -0.38;
const float CAR_MARGIN   = 0.075;

float hash11(float p)
{
    return fract(sin(p)*43758.5453123);
}

float sdCircle(vec2 p, float r)
{
    return length(p) - r;
}

float sdBox(vec2 p, vec2 b)
{
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdRoundBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdCapsule(vec2 p, vec2 a, vec2 b, float r)
{
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

void carSDF(
    vec2 p,
    out float dOut,
    out float dWheels,
    out float dWindow,
    out float dHead,
    out float dTail,
    out float dStripe
){

    float body   = sdRoundBox(p + vec2(0.0, -0.005), vec2(0.055, 0.090), 0.020);
    float cabin  = sdRoundBox(p + vec2(0.0,  0.060), vec2(0.042, 0.048), 0.018);

    vec2 wp = p;
    wp.y = abs(wp.y);
    float wheelR = sdRoundBox(wp - vec2( 0.068, 0.040), vec2(0.014, 0.028), 0.006);
    float wheelL = sdRoundBox(wp - vec2(-0.068, 0.040), vec2(0.014, 0.028), 0.006);
    dWheels = min(wheelR, wheelL);

    float bumperF = sdRoundBox(p + vec2(0.0,  0.110), vec2(0.050, 0.012), 0.008);
    float bumperB = sdRoundBox(p + vec2(0.0, -0.110), vec2(0.050, 0.012), 0.008);

    dOut = body;
    dOut = min(dOut, cabin);
    dOut = min(dOut, dWheels);
    dOut = min(dOut, bumperF);
    dOut = min(dOut, bumperB);

    float winFront = sdRoundBox(p + vec2(0.0, 0.082), vec2(0.028, 0.028), 0.010);
    float winRear  = sdRoundBox(p + vec2(0.0, 0.050), vec2(0.026, 0.018), 0.008);
    float winSideL = sdRoundBox(p + vec2(-0.026, 0.062), vec2(0.010, 0.020), 0.006);
    float winSideR = sdRoundBox(p + vec2( 0.026, 0.062), vec2(0.010, 0.020), 0.006);
    dWindow = min(min(winFront, winRear), min(winSideL, winSideR));

    dStripe = sdRoundBox(p + vec2(0.0, -0.005), vec2(0.010, 0.088), 0.006);

    float h1 = sdCircle(p - vec2(-0.030, 0.106), 0.010);
    float h2 = sdCircle(p - vec2( 0.030, 0.106), 0.010);
    dHead = min(h1, h2);

    float t1 = sdCircle(p - vec2(-0.030,-0.108), 0.010);
    float t2 = sdCircle(p - vec2( 0.030,-0.108), 0.010);
    dTail = min(t1, t2);
}

float sdCar(vec2 p)
{
    float dOut, dW, dWin, dH, dT, dS;
    carSDF(p, dOut, dW, dWin, dH, dT, dS);
    return dOut;
}

float sdObstacle(vec2 p, float type)
{
    float d = 1e5;

    if (type < 0.5)
    {
        d = sdRoundBox(p, vec2(0.040, 0.040), 0.010);
    }
    else if (type < 1.5)
    {
        d = sdCircle(p, 0.045);
    }
    else if (type < 2.5)
    {
        d = sdCapsule(p, vec2(-0.060, 0.0), vec2(0.060, 0.0), 0.020);
    }
    else
    {
        float s = 0.85;
        d = sdCar(p / s) * s;
    }

    return d;
}

float gameSpeed(float t)
{
    float sp = 0.65 + 0.02 * min(t, 25.0);
    return sp;
}
