#ifndef GENERATE_WAVE_INCLUDED
#define GENERATE_WAVE_INCLUDED

struct Wave
{
    half amplitude;
    half direction;
    half wavelength;
    half2 origin;
    half omni;
};

uniform uint _WaveCount;

StructuredBuffer<Wave> _WaveDataBuffer;

struct WaveStruct
{
    float3 position;
    float3 normal;
};

//复制好爽，有种知识从脑中路过的感觉
WaveStruct GerstnerWave(half2 pos, float waveCountMulti, half amplitude, half direction, half wavelength, half omni, half2 omniPos)
{
    WaveStruct waveOut;
    #if defined(_STATIC_WATER)
    float time = 0;
    #else
    float time = _Time.y;
    #endif

    ////////////////////////////////wave value calculations//////////////////////////
    half3 wave = 0; // wave vector
    half w = 6.28318 / wavelength; // 2pi over wavelength(hardcoded)
    half wSpeed = sqrt(9.8 * w); // frequency of the wave based off wavelength
    half peak = 1.5; // peak value, 1 is the sharpest peaks
    half qi = peak / (amplitude * w * _WaveCount);

    direction = radians(direction); // convert the incoming degrees to radians, for directional waves
    half2 dirWaveInput = half2(sin(direction), cos(direction)) * (1 - omni);
    half2 omniWaveInput = (pos - omniPos) * omni;

    half2 windDir = normalize(dirWaveInput + omniWaveInput); // calculate wind direction
    half dir = dot(windDir, pos - (omniPos * omni)); // calculate a gradient along the wind direction

    ////////////////////////////position output calculations/////////////////////////
    half calc = dir * w + -time * wSpeed; // the wave calculation
    half cosCalc = cos(calc); // cosine version(used for horizontal undulation)
    half sinCalc = sin(calc); // sin version(used for vertical undulation)

    // calculate the offsets for the current point
    wave.xz = qi * amplitude * windDir.xy * cosCalc;
    wave.y = ((sinCalc * amplitude)) * waveCountMulti;// the height is divided by the number of waves

    ////////////////////////////normal output calculations/////////////////////////
    half wa = w * amplitude;
    // normal vector
    half3 n = half3(-(windDir.xy * wa * cosCalc),
                    1-(qi * wa * sinCalc));

    ////////////////////////////////assign to output///////////////////////////////
    waveOut.position = wave * saturate(amplitude * 10000);
    waveOut.normal = (n.xzy * waveCountMulti);

    return waveOut;
}

#endif