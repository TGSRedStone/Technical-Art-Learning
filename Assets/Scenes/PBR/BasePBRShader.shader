Shader "PBR/BasePBRShader"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
		_LUT("LUT", 2D) = "white" {}
        _NormalTex ("NormalTex", 2d) = "bump" {}
        _MetallicTex ("MetallicTex", 2d) = "white" {}
        _RoughnessTex ("RoughnessTex", 2d) = "white" {}
        _Tint("Tint", Color) = (1 ,1 ,1 ,1)
		[Gamma] _Metallic("Metallic", Range(0, 1)) = 0
		_Smooth ("Smooth", Range(0, 0.94)) = 0.5
        _LocalNormal ("LocalNormal", range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "ShaderModel" = "4.5"}
        ZWrite On
        Cull Back

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _NORMAL_SETUP
            #pragma shader_feature _METALLIC_SETUP
            #pragma shader_feature _ROUGHNESS_SETUP
            
            #define UNITY_PI            3.14159265359f
            #define UNITY_INV_PI        0.31830988618f

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _LUT_ST;
            float4 _Tint;
            float _Metallic;
            float _Smooth;
            float _LocalNormal;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_LUT); SAMPLER(sampler_LUT);
            TEXTURE2D(_NormalTex); SAMPLER(sampler_NormalTex);
            TEXTURE2D(_MetallicTex); SAMPLER(sampler_MetallicTex);
            TEXTURE2D(_RoughnessTex); SAMPLER(sampler_RoughnessTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldTangentDir : TEXCOORD3;
                float3 worldBitangentDir : TEXCOORD4;
            };

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

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldTangentDir = normalize(TransformObjectToWorld(v.tangent.xyz));
                o.worldBitangentDir = normalize(cross(o.worldNormal, o.worldTangentDir) * v.tangent.w);
                return o;
            }

            //间接光有问题
            float4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldPos = i.worldPos;
                float3 worldLightDir = _MainLightPosition.xyz;
                float3 worldViewDir = normalize(GetWorldSpaceViewDir(worldPos));
                float3 halfVector = SafeNormalize(worldViewDir + worldLightDir);
                
#ifdef _NORMAL_SETUP
                float3 normalTex = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv));
                float3x3 tangentTransform = float3x3(i.worldTangentDir, i.worldBitangentDir, i.worldNormal);
                float3 worldNormalTex = mul(normalTex, tangentTransform);
                float3 finiNormal = lerp(worldNormal, worldNormalTex, _LocalNormal);
#else
                float3 finiNormal = worldNormal;
#endif

#ifdef _METALLIC_SETUP
                _Metallic = lerp(0, SAMPLE_TEXTURE2D(_MetallicTex, sampler_MetallicTex, i.uv).r, _Metallic);
#endif

#ifdef _ROUGHNESS_SETUP
                _Smooth = lerp(0, 1 - SAMPLE_TEXTURE2D(_RoughnessTex, sampler_RoughnessTex, i.uv).r, _Smooth);
#endif

                float perceptualRoughness = 1.0 - _Smooth;
	            float roughness = perceptualRoughness * perceptualRoughness;
	            float roughness2 = roughness * roughness;

                float NDotL = saturate(dot(finiNormal, worldLightDir)) + 1e-5f;
                float NDotV = saturate(dot(finiNormal, worldViewDir)) + 1e-5f;
                float VDotH = saturate(dot(worldViewDir, halfVector)) + 1e-5f;
                float LDotH = saturate(dot(worldLightDir, halfVector)) + 1e-5f;
                float NDotH = saturate(dot(finiNormal, halfVector)) + 1e-5f;

                float3 Albedo = _Tint.rgb * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb;
                
                float D = roughness2 * UNITY_INV_PI / pow(NDotH * NDotH * (roughness2 - 1.0) + 1.0, 2) + 1e-5f;
// return D;
                
                float kG = pow(roughness2 + 1.0 , 2.0) / 8;
                float GL = NDotL / (NDotL * (1.0 - kG) + kG);
                float GV = NDotV / (NDotV * (1.0 - kG) + kG);
                float G = GL * GV;
// return G;
                
                float3 F0 = lerp(float3(0.04, 0.04, 0.04), Albedo, _Metallic);
                float3 F = F0 + (1 - F0) * exp2((-5.55473 * VDotH - 6.98316) * VDotH);
// return float4(F, 1);
                
                float3 specularResult = (D * G * F * 0.25) / (NDotV * NDotL);

                float3 kd = (1 - F) * (1 - _Metallic);
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
                
                float kdLast = (1 - Flast.r) * (1 - _Metallic);

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
            ENDHLSL
        }
    }
    CustomEditor "BasePBRshaderGUI"
}
