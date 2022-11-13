Shader "TheBookOfShaders/Shapes/BoxGraphics"
{
    Properties
    {
        _Resolution ("Resolution", float) = 1
        _a ("a", float) = 0
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
            float _Resolution;
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
                float2 uv = i.uv * _Resolution;

                float3 pct = StepBoxMask(0.4, float2(uv.x + 0.3, uv.y - 0.4)) * float3(1, 0, 0);
                pct += StepBoxMask(0.4, float2(uv.x + 0.3, uv.y - 0.2)) * float3(0, 1, 0);
                pct += StepBoxMask(0.4, float2(uv.x + 0.3, uv.y - 0.0)) * float3(0, 0, 1);

                pct += StepBoxMask(0.4, float2(uv.x + 0.0, uv.y - 0.4)) * float3(0, 1, 1);
                pct += StepBoxMask(0.4, float2(uv.x + 0.0, uv.y - 0.2)) * float3(1, 1, 0);
                pct += StepBoxMask(0.4, float2(uv.x + 0.0, uv.y - 0.0)) * float3(1, 0, 1);
                
                float2 l = step(0.1, uv.x);
                pct += 1 - l.x * l.y;

                l = step(0.4, uv.x) - step(0.3, uv.x);
                pct += l.x * l.y;

                l = step(0.7, uv.x) - step(0.6, uv.x);
                pct += l.x * l.y;

                float2 t = step(0.3, uv.y) - step(0.4, uv.y);
                pct += t.x * t.y;
                
                return float4(pct, 1);
            }
            ENDHLSL
        }
    }
}
