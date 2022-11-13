Shader "TheBookOfShaders/Matrix/FUI"
{
    Properties
    {
        
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)

            CBUFFER_END

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

            float2x2 Scale(float2 scale)
            {
                return float2x2(scale.x, 0.0, 0.0, scale.y);
            }

            float2x2 Rotate2d(float angle)
            {
                return float2x2(cos(angle), -sin(angle), sin(angle), cos(angle));
            }

            float box(in float2 _st, in float2 _size)
            {
                _size = 0.5 - _size * 0.5;
                float2 uv = smoothstep(_size, _size + 0.001, _st);
                uv *= smoothstep(_size, _size + 0.001, 1.0 - _st);
                return uv.x * uv.y;
            }

            float StepBoxMask(float a, float2 uv)
            {
                float2 bl = step(a, uv);
                float pct = bl.x * bl.y;

                float2 tr = step(a, 1 - uv);
                return pct *= tr.x * tr.y;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 col = 0;
                float2 uv = i.uv;

                float r = length(uv - 0.5);
                //circular
                col += step(0.1, r) - step(0.105, r);
                col += step(0.2, r) - step(0.205, r);
                col += saturate(step(0.4, r) - step(0.405, r) - box(uv, float2(1, 0.2 / 2.0)) - box(uv, float2(0.2 / 2.0, 1)));
                col *= float3(0.74,0.95,1.00);
                //rotateLine
                float2 ScanLineUV = uv - 0.5;
                ScanLineUV = mul(ScanLineUV, Rotate2d(_Time.y));
                ScanLineUV += 0.5;
                col += box(ScanLineUV, float2(0.4, 0.02 / 2.0));
                col -= box(ScanLineUV, float2(0.2, 0.02 / 2.0));
                ScanLineUV = uv - 0.5;
                ScanLineUV = mul(ScanLineUV, Rotate2d(_Time.y * 0.5));
                ScanLineUV += 0.5;
                col += box(ScanLineUV, float2(0.2, 0.02 / 4.0)) + box(ScanLineUV, float2(0.02 / 4.0, 0.2));
                //Box
                col += StepBoxMask(0.49, uv);
                
                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}
