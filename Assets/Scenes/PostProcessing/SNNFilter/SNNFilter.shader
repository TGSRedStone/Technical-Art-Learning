Shader "PostProcessing/SNNFilter"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            cull Off
            zwrite Off
            ztest Always

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _half_width;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float CalcDistance(in float3 c0, in float3 c1)
            {
                float3 sub = c0 - c1;
                return dot(sub, sub);
            }

            // Symmetric Nearest Neighbor
            float3 SNN(float2 uv)
            {
                float2 src_size = _ScreenParams.xy;
                float2 inv_src_size = 1.0f / src_size;

                float3 c0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;

                float4 sum = float4(0.0f, 0.0f, 0.0f, 0.0f);

                for (int i = 0; i <= _half_width; ++i)
                {
                    float3 c1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(+i, 0) * inv_src_size).rgb;
                    float3 c2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-i, 0) * inv_src_size).rgb;

                    float d1 = CalcDistance(c1, c0);
                    float d2 = CalcDistance(c2, c0);
                    if (d1 < d2)
                    {
                        sum.rgb += c1;
                    }
                    else
                    {
                        sum.rgb += c2;
                    }
                    sum.a += 1.0f;
                }
                for (int j = 1; j <= _half_width; ++j)
                {
                    for (int i = -_half_width; i <= _half_width; ++i)
                    {
                        float3 c1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(+i, +j) * inv_src_size).rgb;
                        float3 c2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-i, -j) * inv_src_size).rgb;

                        float d1 = CalcDistance(c1, c0);
                        float d2 = CalcDistance(c2, c0);
                        if (d1 < d2)
                        {
                            sum.rgb += c1;
                        }
                        else
                        {
                            sum.rgb += c2;
                        }
                        sum.a += 1.0f;
                    }
                }
                return sum.rgb / sum.a;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                return float4(SNN(i.uv), 1);
            }
            ENDHLSL
        }
    }
}