//Ideally I'd use uniforms instead of #defines, but it doesn't look
//like ShaderToy supports custom uniforms

//Controls the size of the checkers (in pixels)
#define checkerSize 32.0f

//Colors used
#define colA vec3(0,0,0)
#define colB vec3(1,1,1)

//Strip the integer part, return only the decimal part.
float getDecimalPart(float x) { return x-float(int(x)); }

//Boolean exclusive or, because I can't find a GLSL function for it
bool xor(bool a, bool b) { return (a||b) && !(a&&b);  }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    //Must be doubled, because we're comparing the decimal parts with 0.5
    vec2 uv = vec2(fragCoord.x/2.0f/checkerSize, fragCoord.y/2.0f/checkerSize);
    
    //Is the pixel using color B?
    bool pxCol = xor(getDecimalPart(uv.x) > 0.5f, getDecimalPart(uv.y) > 0.5f);
    
    // Output to screen
    fragColor = vec4(pxCol?colB:colA, 1);
}