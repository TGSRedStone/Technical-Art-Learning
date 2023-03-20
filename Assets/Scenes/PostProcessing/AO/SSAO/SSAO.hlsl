#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
TEXTURE2D(_AOTex); SAMPLER(sampler_AOTex);
float4x4 _invVPMatrix;

float Hash(float2 p)
{
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

//x,y,z [0 - 1]
float3 GetRandomVec(float2 p)
{
    float3 vec = float3(0, 0, 0);
    vec.x = Hash(p) * 2 - 1;
    vec.y = Hash(p * p) * 2 - 1;
    vec.z = Hash(p * p * p) * 2 - 1;
    return normalize(vec);
}

//x,y [0 - 1]
//z [0.2 - 1]
//解决自遮挡问题
float3 GetRandomVecHalf(float2 p)
{
    float3 vec = float3(0, 0, 0);
    vec.x = Hash(p) * 2 - 1;
    vec.y = Hash(p * p) * 2 - 1;
    vec.z = saturate(Hash(p * p * p) + 0.2);
    return normalize(vec);
}

float GetEyeDepth(float2 uv)
{
    float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
    return LinearEyeDepth(rawDepth, _ZBufferParams);
}

float4 GetWorldPos(float2 uv)
{
    float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
#if defined(UNITY_REVERSED_Z)
    rawDepth = 1 - rawDepth;
#endif
    float4 ndc = float4(uv.xy * 2 - 1, rawDepth * 2 - 1, 1);
    float4 wPos = mul(_invVPMatrix, ndc);
    wPos /= wPos.w;
    return wPos;
}

float3 GetWorldNormal(float2 uv)
{
    float3 normal = SampleSceneNormals(uv);
    return mul((float3x3)unity_CameraToWorld, normal);
}
