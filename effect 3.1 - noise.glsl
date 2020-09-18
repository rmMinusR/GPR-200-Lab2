#define PI 3.1415926535
#define SEED 0xcbc30a02

//Heavily modified Krubbles' pseudorandom, see post on GDN:
//https://discordapp.com/channels/280521930371760138/280523185819222016/756170068496220242
int random2D(uint x, uint y, uint z, uint seed) {
    //Fix white artifacting at x=0, y=0, seed=0 by wrapping a certain region
    //Terrible practice but they'll never know...
    x    = x    | uint(0xf000000);
    y    = y    | uint(0xf000000);
    z    = z    | uint(0xf000000);
    seed = seed | uint(0xf000000);
    
    uint random = x*(y^seed) + y*(z^seed) + z*(x^seed);
    random ^= seed;
    random *= x * y * z;
    random ^= random >> 11;
    random ^= random << 5;
    random ^= random >> 3;
    return int(random);
}
//Wrapper
int random2D(int x, int y, int z, int seed) {
    return random2D(uint(x), uint(y), uint(z), uint(seed));
}

//Strip the integer part, return only the decimal part.
float getDecimalPart(float x) {
    return x>0.?
        x-float(int(x)):
    	x-float(int(x))+1.;
}

//Introduce further entropy and scale it to 0..1
float noise(ivec3 pos, int seed) {
    float r = float(random2D(pos.x, pos.y, pos.z, seed));
    return getDecimalPart(r/float(2<<12) + r/float(2<<16));
}

//Float range remap, pretty boilerplate
float fmap(float x, float lo1, float hi1, float lo2, float hi2) { return (x-lo1)/(hi1-lo1)*(hi2-lo2)+lo2; }

float clamp01(float x) { return x < 0. ? 0. : ( x > 1. ? 1. : x ); }

//Linear interpolate
float lerp(float x, float a, float b) { return x*b+(1.0-x)*a; }

//Pick and choose values
ivec3 pnc(ivec3 a, ivec3 b, bool x, bool y, bool z) { return ivec3(x?b.x:a.x, y?b.y:a.y, z?b.z:a.z); }

//Antialias of noise()
float aaNoise(vec3 pos, int seed) {
    //Decimal Part
    vec3 dp = vec3( getDecimalPart(pos.x), getDecimalPart(pos.y), getDecimalPart(pos.z) );
    
    //Lower and upper corners
    ivec3 lb = ivec3(round(pos.x-dp.x), round(pos.y-dp.y), round(pos.z-dp.z));
    ivec3 hb = lb + ivec3(1,1,1);
    
    /*
    return noise(lb);
    /*/
    return lerp(dp.z,
        lerp(dp.y,
            lerp( dp.x, noise(pnc(lb, hb, false, false, false), seed), noise(pnc(lb, hb, true, false, false), seed) ),
            lerp( dp.x, noise(pnc(lb, hb, false,  true, false), seed), noise(pnc(lb, hb, true,  true, false), seed) )
        ),
        lerp(dp.y,
            lerp( dp.x, noise(pnc(lb, hb, false, false, true), seed), noise(pnc(lb, hb, true, false, true), seed) ),
            lerp( dp.x, noise(pnc(lb, hb, false,  true, true), seed), noise(pnc(lb, hb, true,  true, true), seed) )
        )
    ); //*/
}

//Eww, more loops.
//Generates a fibonacci number pair such that pair.x > pair.y > pair.z
vec3 fibonacci2(int n) {
    vec3 val = vec3(2,1,1);
    
    for(int i = 0; i < n; i++) {
        float sum = val.x + val.y;
        val.z = val.y;
        val.y = val.x;
        val.x = sum;
    }
    
    return val;
}

//XYZ based on the fibonacci sequence.
//Used to translate noise layers and hide artifacts
vec3 fibonacci_offset(int n) {
    vec3 v = fibonacci2(n);
    
    return vec3(
        (n&1)!=0? v.x : -v.x,
        (n&2)!=0? v.y : -v.y,
        (n&4)!=0? v.z : -v.z
    );
}

//It loops. Gross!
//Also it's artifact-prone. Oh well.
float fractalNoise(vec3 pos, int octaves, float octaveScaling, float octaveWeight, int seed) {
    float f = 0.;
    float octavicSum = 0.;
    
    for(int i = 0; i < octaves; i++) {
        //f += aaNoise( pow(octaveScaling, float(i))*pos ) * pow(octaveWeight, float(octaves-i+1)) * (1.-octaveWeight);
        float layer = aaNoise( pow(octaveScaling, float(i))*pos + fibonacci_offset(i), seed);
        f +=  layer * pow(octaveWeight, float(i));
        octavicSum += pow(octaveWeight, float(i));
    }
    
    return f/octavicSum;
}

//Curve towards 0 and 1 (increase contrast)
//My own devising assisted by Desmos Graphing Calculator
float curve(float x, float c) {
    if(x < 0.5) {
        return pow(2.*x, c)/2.;
    } else {
        return 1.-pow(2.-2.*x, c)/2.;
    }
}

//Largely untested
vec3 HSVtoRGB(float h, float s, float v) {
    vec3 col = vec3(
        fmap(cos(h*2.*PI + 0.0/3.0*PI) , -1.0, 1.0, 0.0, 1.0),
        fmap(cos(h*2.*PI + 2.0/3.0*PI) , -1.0, 1.0, 0.0, 1.0),
        fmap(cos(h*2.*PI + 4.0/3.0*PI) , -1.0, 1.0, 0.0, 1.0)
    ) * s;
    
    return col*v+(1.-v)*vec3(1.,1.,1.);
}

vec3 fractalNoise3(vec3 pos, int octaves, float octaveScaling, float octaveWeight, int seed) {
    return vec3(
        fractalNoise(pos, octaves, octaveScaling, octaveWeight, seed^0x11111111),
        fractalNoise(pos, octaves, octaveScaling, octaveWeight, seed^0x22222222),
        fractalNoise(pos, octaves, octaveScaling, octaveWeight, seed^0x44444444)
    );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 access_pos = vec3(fragCoord, 0);
    
    access_pos.z = iTime*32.;
    
    //Zoom scale
    access_pos.xy /= 1.;
    
    //Put (0,0) in the center of the screen, so we can spot artifacts
    access_pos.xy -= vec2(iResolution)/2.;
    
    vec3 v = fractalNoise3(access_pos.xyz, 8, pow(1.61803399, -1.), 1.2, SEED);
    
    //Attempt to fix distribution
    //Not ideal but "good enough"
    v.x = curve(clamp01(fmap(v.x, 0.25, 0.75, 0., 1.)), 3.2);
    v.y = curve(clamp01(fmap(v.y, 0.25, 0.75, 0., 1.)), 3.2);
    v.z = curve(clamp01(fmap(v.z, 0.25, 0.75, 0., 1.)), 3.2);
    
    //vec3 col = HSVtoRGB(f0, f1, f2);
    vec3 col = v;
    
    // Output to screen
    fragColor = vec4(col,1.);
}