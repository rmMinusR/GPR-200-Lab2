#define circleCenter (iResolution.xy/2.0f)

#define circleSizeMin 150.0f
#define circleSizeMax 200.0f

//How fast the colors should radiate from the center
#define colorWaveExpandSpeed 1.0f

//Times per second the circle should "breathe"
#define circleBreatheRate 1.5f

#define PI 3.14159265358979
#define circleSizeAvg ((circleSizeMax+circleSizeMin)/2.0f)

//Strip the integer part, return only the decimal part.
float getDecimalPart(float x) { return x-float(int(x)); }

//Float range remap, pretty boilerplate
float fmap(float x, float lo1, float hi1, float lo2, float hi2) { return (x-lo1)/(hi1-lo1)*(hi2-lo2)+lo2; }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;
	
    //Circle's size this frame
    float circleSize = fmap(sin(iTime*circleBreatheRate), -1.0f, 1.0f, circleSizeMin, circleSizeMax);
    
    //Distance to center, normalized so that 0 = center and 1 = circle's average radius
    float relDist = distance(circleCenter, fragCoord)/circleSizeAvg;
    
    // Pixel color, pre-invert.
    vec3 col;
    
    //Not exactly HSV to RGB, but good enough.
    col = vec3(
        fmap(sin(relDist + 0.0/3.0*PI - iTime*colorWaveExpandSpeed) , -1.0, 1.0, 0.0, 1.0),
        fmap(sin(relDist + 2.0/3.0*PI - iTime*colorWaveExpandSpeed) , -1.0, 1.0, 0.0, 1.0),
        fmap(sin(relDist + 4.0/3.0*PI - iTime*colorWaveExpandSpeed) , -1.0, 1.0, 0.0, 1.0)
    );
    
    //Would ordinarily write to fragColor but it's write only, and I want to change it later...
    vec4 col_out = vec4(col, 1);
    
    //Invert color if within circle
    if(distance(circleCenter, fragCoord)/circleSize > 1.0f) {
        col_out = vec4(vec3(1,1,1)-col.xyz,1.0);
    }
    
    // Output to screen
    fragColor = col_out;
}