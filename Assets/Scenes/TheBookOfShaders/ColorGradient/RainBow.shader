Shader "TheBookOfShaders/ColorGradient/RainBow"
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
            float _a;
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

            float plot (float2 st, float pct)
            {
                return step( pct - 0.1, st.y) - step(pct + 0.1, st.y);
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
                float2 uv = abs(i.uv - 0.5) * _Resolution;
                float3 colorA = float3(1, 0, 0);
                float3 colorB = float3(1, 0.647, 0);
                float3 colorC = float3(1, 1, 0);
                float3 colorD = float3(0, 1, 0);
                float3 colorE = float3(0, 0.498, 1);
                float3 colorF = float3(0, 0, 1);
                float3 colorG = float3(0.646, 0, 1);
                float3 col = 0;
                float pct = 1 - length(uv);
                col += lerp(colorA, colorB, smoothstep(0.10, 0.20, pct)) * (step(pct, 0.20) - step(pct, 0.10));
                col += lerp(colorB, colorC, smoothstep(0.20, 0.30, pct)) * (step(pct, 0.30) - step(pct, 0.20));
                col += lerp(colorC, colorD, smoothstep(0.30, 0.40, pct)) * (step(pct, 0.40) - step(pct, 0.30));
                col += lerp(colorD, colorE, smoothstep(0.40, 0.50, pct)) * (step(pct, 0.50) - step(pct, 0.40));
                col += lerp(colorE, colorF, smoothstep(0.50, 0.60, pct)) * (step(pct, 0.60) - step(pct, 0.50));
                col += lerp(colorF, colorG, smoothstep(0.60, 0.70, pct)) * (step(pct, 0.70) - step(pct, 0.60));
                return float4(col * step(_a, i.uv.y), 1);
            }
            ENDHLSL
        }
    }
}
