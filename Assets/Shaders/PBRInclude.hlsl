#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#define UNITY_PI            3.14159265359f
#define UNITY_INV_PI        0.31830988618f

TEXTURE2D(_LUT); SAMPLER(sampler_LUT);

float Pow5(float x)
{
    return (x * x) * (x * x) * x;
}

half DisneyDiffuse(half NdotV, half NdotL, half LdotH, half roughness,half3 baseColor)
{
    half fd90 = 0.5 + 2 * LdotH * LdotH * roughness;
    // Two schlick fresnel term
    half lightScatter   = (1 + (fd90 - 1) * Pow5(1 - NdotL));
    half viewScatter    = (1 + (fd90 - 1) * Pow5(1 - NdotV));
    return ( baseColor.r / UNITY_PI) * lightScatter * viewScatter;
}

float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

float4 PBR(float3 worldNormal, float3 worldViewDir, float3 Albedo, float smooth, float metallic)
{
    float3 worldLightDir = _MainLightPosition.xyz;
    float3 halfVector = SafeNormalize(worldViewDir + worldLightDir);

    float3 finiNormal = worldNormal;

    float perceptualRoughness = 1.0 - smooth;
    float roughness = perceptualRoughness * perceptualRoughness;
    float roughness2 = roughness * roughness;

    float NDotL = saturate(dot(finiNormal, worldLightDir)) + 1e-5f;
    float NDotV = saturate(dot(finiNormal, worldViewDir)) + 1e-5f;
    float VDotH = saturate(dot(worldViewDir, halfVector)) + 1e-5f;
    float LDotH = saturate(dot(worldLightDir, halfVector)) + 1e-5f;
    float NDotH = saturate(dot(finiNormal, halfVector)) + 1e-5f;

    float D = roughness2 * UNITY_INV_PI / pow(NDotH * NDotH * (roughness2 - 1.0) + 1.0, 2) + 1e-5f;
    // return D;

    float kG = pow(roughness2 + 1.0, 2.0) / 8;
    float GL = NDotL / (NDotL * (1.0 - kG) + kG);
    float GV = NDotV / (NDotV * (1.0 - kG) + kG);
    float G = GL * GV;
    // return G;

    float3 F0 = lerp(float3(0.04, 0.04, 0.04), Albedo, metallic);
    float3 F = F0 + (1 - F0) * exp2((-5.55473 * VDotH - 6.98316) * VDotH);
    // return float4(F, 1);

    float3 specularResult = (D * G * F * 0.25) / (NDotV * NDotL);

    float3 kd = (1 - F) * (1 - metallic);
    float3 diffuse = kd * Albedo * _MainLightColor.rgb * NDotL;
    // float3 diffuse = kd * Albedo * _MainLightColor.rgb * BurleyBRDF(NDotL, NDotV, LDotH, roughness);
    float3 specColor = specularResult * _MainLightColor.rgb * NDotL * UNITY_PI;
    float3 directLightResult = diffuse + specColor;

    float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
    float3 reflectVec = reflect(-worldViewDir, finiNormal);

    half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
    half4 rgbm = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVec, mip);

    float3 iblSpecular = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);

    float2 envBDRF = SAMPLE_TEXTURE2D(_LUT, sampler_LUT, float2(lerp(0.0, 0.99, NDotV), lerp(0.0, 0.99, roughness))).rg;

    float3 Flast = fresnelSchlickRoughness(max(NDotV, 0.0), F0, roughness);

    float kdLast = (1 - Flast.r) * (1 - metallic);

    float3 ambientContrib = SampleSH(finiNormal);
    float3 ambient = 0.03 * Albedo;
    float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambientContrib);
    float3 iblDiffuseResult = iblDiffuse * kdLast * Albedo;
    // return float4(iblDiffuseResult, 1);

    float3 iblSpecularResult = iblSpecular * (Flast * envBDRF.r + envBDRF.g);
    // return float4(iblSpecularResult, 1);

    float3 indirectLightResult = iblDiffuseResult + iblSpecularResult;
    // return float4(indirectLightResult, 1);

    float4 result = float4(directLightResult + indirectLightResult, 1);

    return result;
}
