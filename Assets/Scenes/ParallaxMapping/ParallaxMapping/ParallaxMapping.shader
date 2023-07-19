Shader "ParallaxMapping/ParallaxMapping"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        [NoScaleOffset] _ParallaxMap ("Parallax", 2D) = "black" {}
        _ParallaxStrength ("Parallax Strength", Range(0, 0.1)) = 0
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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float _ParallaxStrength;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_ParallaxMap);
            SAMPLER(sampler_ParallaxMap);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 tangent : TANGENT;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 tangentViewDir : TEXCOORD1;
            };

            inline float3 ObjSpaceViewDir(float4 v)
            {
                float3 objSpaceCameraPos = TransformWorldToObject(_WorldSpaceCameraPos.xyz);
                return objSpaceCameraPos - v.xyz;
            }

            inline float GetParallaxHeight(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_ParallaxMap, sampler_ParallaxMap, uv).r;
            }

            float2 ParallaxOffset(float2 uv, float2 tangentViewDir)
            {
                float height = GetParallaxHeight(uv);
                height -= 0.5;
                height *= _ParallaxStrength;
                return tangentViewDir * height;
            }

            float2 ParallaxRaymarching(float2 uv, float2 viewDir)
            {
                #define PARALLAX_RAYMARCHING_STEPS 10
                float2 uvOffset = 0;
                float stepSize = 1.0 / PARALLAX_RAYMARCHING_STEPS;
                float2 uvDelta = viewDir * (stepSize * _ParallaxStrength);
                float stepHeight = 1;
                float surfaceHeight = GetParallaxHeight(uv);

                float2 prevUVOffset = uvOffset;
                float prevStepHeight = stepHeight;
                float prevSurfaceHeight = surfaceHeight;

                for (int i = 1; i < PARALLAX_RAYMARCHING_STEPS && stepHeight > surfaceHeight; i++)
                {
                    float2 prevUVOffset = uvOffset;
                    float prevStepHeight = stepHeight;
                    float prevSurfaceHeight = surfaceHeight;

                    uvOffset -= uvDelta;
                    stepHeight -= stepSize;
                    surfaceHeight = GetParallaxHeight(uv + uvOffset);
                }

                float prevDifference = prevStepHeight - prevSurfaceHeight;
                float difference = surfaceHeight - stepHeight;
                float t = prevDifference / (prevDifference + difference);
                uvOffset = lerp(prevUVOffset, uvOffset, t);

                return uvOffset;
            }

            float2 ParallaxRaymarchingBinarySearch(float2 uv, float2 viewDir)
            {
                #define PARALLAX_RAYMARCHING_SEARCH_STEPS 5
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
                float3x3 objectToTangent = float3x3(
                    v.tangent.xyz,
                    cross(v.normal, v.tangent.xyz) * v.tangent.w,
                    v.normal);
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                i.tangentViewDir = normalize(i.tangentViewDir);
                i.tangentViewDir.xy /= i.tangentViewDir.z + 0.42;
                float2 uvOffset = ParallaxRaymarchingBinarySearch(i.uv, i.tangentViewDir.xy);
                i.uv += uvOffset;
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                return col;
            }
            ENDHLSL
        }
    }
}