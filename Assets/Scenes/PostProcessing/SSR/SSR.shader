Shader "PostProcessing/SSR"
{
    Properties
    {
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

            #define MAXDISTANCE 15
            #define STEP_COUNT 100
            #define THICKNESS 0.3
            #define STEP_SIZE 0.1

            float4 _NearTopLeftPoint;
            float4 _NearXVector;
            float4 _NearYVector;

            TEXTURE2D(_SourceTex);
            SAMPLER(sampler_SourceTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 GetSource(half2 uv)
            {
                return SAMPLE_TEXTURE2D(_SourceTex, sampler_SourceTex, uv);
            }

            void ReconstructUVAndDepth(float3 worldPos, out float2 uv, out float depth)
            {
                float4 clipPos = mul(UNITY_MATRIX_VP, worldPos);
                uv = float2(clipPos.x, clipPos.y * _ProjectionParams.x) / clipPos.w * 0.5 + 0.5;
                depth = clipPos.w;
            }

            half3 ReconstructViewPos(float2 uv, float linearEyeDepth)
            {
                uv.y = 1.0 - uv.y;

                float zScale = linearEyeDepth * (1.0 / _ProjectionParams.y);
                float3 viewPos = _NearTopLeftPoint.xyz + _NearXVector.xyz * uv.x + _NearYVector.xyz * uv.y;
                viewPos *= zScale;
                return viewPos;
            }

            float4 frag(v2f i) : SV_Target
            {
                float rawDepth = SampleSceneDepth(i.uv);
                float linearEyeDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                float3 viewNormal = SampleSceneNormals(i.uv);
                float3 viewPos = ReconstructViewPos(i.uv, linearEyeDepth);
                float3 viewDir = normalize(viewPos);
                float3 reflectDir = normalize(reflect(viewDir, viewNormal));

                float2 uv;
                float depth;

                UNITY_UNROLL
                for (int a = 0; a < STEP_COUNT; a++)
                {
                    float3 newViewPos = viewPos + reflectDir * STEP_SIZE * a;
                    float2 newUV;
                    float stepDepth;
                    ReconstructUVAndDepth(newViewPos, newUV, stepDepth);
                    float stepRawDepth = SampleSceneDepth(newUV);
                    float stepSurfaceDepth = LinearEyeDepth(stepRawDepth, _ZBufferParams);
                    if (stepSurfaceDepth < stepDepth && stepDepth < stepSurfaceDepth + THICKNESS)
                        return GetSource(newUV);
                }
                return half4(0.0, 0.0, 0.0, 1.0);
            }
            ENDHLSL
        }
    }
}