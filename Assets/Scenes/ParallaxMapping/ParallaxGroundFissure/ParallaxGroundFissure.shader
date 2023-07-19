Shader "Shaders/ParallaxGroundFissure"
{
    Properties
    {
        _ParallaxStrength("ParallaxStrength", Range(0 ,0.2)) = 0.1
        _LocalNormal ("LocalNormal", range(0, 1)) = 0.5
        _AOStength ("AOStength", range(0, 1)) = 0.5
        [HDR]_EmissionColor ("EmissionColor", color) = (1, 1, 1, 1)

        _MainTex ("MainTex", 2d) = "white" {}
        _HeightMap ("HeightMap", 2D) = "white" {}
        _LUT("LUT", 2D) = "white" {}
        _NormalTex ("NormalTex", 2d) = "bump" {}
        _MetallicTex ("MetallicTex", 2d) = "white" {}
        _RoughnessTex ("RoughnessTex", 2d) = "white" {}
        _EmissionTex ("EmissionTex", 2d) = "white" {}
        _AOTex ("AOTex", 2d) = "white" {}

    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Assets/Shaders/PBRInclude.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _ParallaxStrength;
            float4 _EmissionColor;
            float _AOStength;
            CBUFFER_END

            TEXTURE2D(_HeightMap);
            SAMPLER(sampler_HeightMap);
            TEXTURE2D(_EmissionTex);
            SAMPLER(sampler_EmissionTex);
            TEXTURE2D(_AOTex);
            SAMPLER(sampler_AOTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldTangentDir : TEXCOORD2;
                float3 worldBitangentDir : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
                float3 viewTS : TEXCOORD5;
            };

            float GetParallaxHeight(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).r;
            }

            //陡视差映射
            float2 SteepParallaxMapping(float2 uv, float3 viewTS)
            {
                float maxLayers = 100; //最大步进次数

                float stepSize = 1 / maxLayers; //单次步进长度
                float layerHeight = stepSize; //单层高度
                float2 uvDelta = _ParallaxStrength * viewTS.xy / viewTS.z * stepSize; //单次uv偏移量

                float2 uvOffset = 0;
                float2 currentUV = uv;
                float stepHeight = 1.0; //步进初始高度

                float heightMap = GetParallaxHeight(currentUV); //采样初始高度信息
                for (int i = 1; i < maxLayers && stepHeight > heightMap; i++)
                {
                    uvOffset -= uvDelta; //uv偏移量累减
                    stepHeight -= layerHeight; //步进高度累减
                    heightMap = GetParallaxHeight(currentUV + uvOffset); //重新采样
                }
                return uvOffset;
            }

            float2 ParallaxOcclusionMapping(float2 uv, float3 viewTS)
            {
                float maxLayers = 100; //最大步进次数

                float stepSize = 1 / maxLayers; //单次步进长度
                float layerHeight = stepSize; //单层高度
                float2 uvDelta = _ParallaxStrength * viewTS.xy / viewTS.z * stepSize; //单次uv偏移量

                float2 uvOffset = 0;
                float2 currentUV = uv;
                float stepHeight = 1.0; //步进初始高度

                float heightMap = GetParallaxHeight(currentUV); //采样初始高度信息

                for (int i = 1; i < maxLayers && stepHeight > heightMap; i++)
                {
                    uvOffset -= uvDelta; //uv偏移量累减
                    stepHeight -= layerHeight; //步进高度累减
                    heightMap = GetParallaxHeight(currentUV + uvOffset);
                }

                float2 perUV = uvOffset + uvDelta;
                float afterHeight = heightMap - stepHeight;
                float beforeHeight = GetParallaxHeight(perUV) - stepHeight + layerHeight;
                float weight = afterHeight / (afterHeight - beforeHeight);
                uvOffset = perUV * weight + uvOffset * (1 - weight);

                return uvOffset;
            }

            float2 ParallaxRaymarchingBinarySearch(float2 uv, float2 viewDir)
            {
                #define PARALLAX_RAYMARCHING_STEPS 100
                #define PARALLAX_RAYMARCHING_SEARCH_STEPS 10
                float2 uvOffset = 0;
                float stepSize = 1.0 / PARALLAX_RAYMARCHING_STEPS;
                float2 uvDelta = viewDir * (stepSize * _ParallaxStrength);
                float stepHeight = 1;
                float surfaceHeight = GetParallaxHeight(uv);

                for (int i = 1; i < PARALLAX_RAYMARCHING_STEPS && stepHeight > surfaceHeight; i++)
                {
                    uvOffset -= uvDelta;
                    stepHeight -= stepSize;
                    surfaceHeight = GetParallaxHeight(uv + uvOffset);
                }

                for (int i = 0; i < PARALLAX_RAYMARCHING_SEARCH_STEPS; i++)
                {
                    uvDelta *= 0.5;
                    stepSize *= 0.5;

                    if (stepHeight < surfaceHeight)
                    {
                        uvOffset += uvDelta;
                        stepHeight += stepSize;
                    }
                    else
                    {
                        uvOffset -= uvDelta;
                        stepHeight -= stepSize;
                    }

                    surfaceHeight = GetParallaxHeight(uv + uvOffset);
                }

                return uvOffset;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                float3x3 objectToTangent = float3x3(v.tangent.xyz, cross(v.normal, v.tangent.xyz) * v.tangent.w,
                                                    v.normal);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                float3 objectView = TransformWorldToObjectDir(GetWorldSpaceViewDir(o.worldPos));
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldTangentDir = normalize(TransformObjectToWorld(v.tangent.xyz));
                o.worldBitangentDir = normalize(cross(o.worldNormal, o.worldTangentDir) * v.tangent.w);
                o.viewTS = mul(objectToTangent, objectView);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldPos = i.worldPos;
                float3 worldViewDir = normalize(GetWorldSpaceViewDir(worldPos));
                i.viewTS = normalize(i.viewTS);
                i.viewTS.xy /= i.viewTS.z + 0.42;

                i.uv += ParallaxRaymarchingBinarySearch(i.uv, i.viewTS);

                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float3 smooth = SAMPLE_TEXTURE2D(_RoughnessTex, sampler_RoughnessTex, i.uv);
                float3 metallic = SAMPLE_TEXTURE2D(_MetallicTex, sampler_MetallicTex, i.uv);
                float3 normalTex = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv));
                float3x3 tangentTransform = float3x3(i.worldTangentDir, i.worldBitangentDir, i.worldNormal);
                float3 worldNormalTex = mul(normalTex, tangentTransform);
                float3 finiNormal = lerp(worldNormal, worldNormalTex, _LocalNormal);
                float ao = SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, i.uv).r;
                float emission = SAMPLE_TEXTURE2D(_EmissionTex, sampler_EmissionTex, i.uv).r;

                float4 result = PBR(finiNormal, worldViewDir, albedo, smooth, metallic);

                result *= lerp(1, ao, _AOStength);

                result = lerp(result, emission * _EmissionColor, emission * ((sin(_Time.y) * 0.5 + 0.5) + 0.1));

                return result;
            }
            ENDHLSL
        }
    }
}