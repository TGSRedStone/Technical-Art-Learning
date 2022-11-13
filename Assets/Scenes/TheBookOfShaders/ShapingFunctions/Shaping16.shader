Shader "TheBookOfShaders/ShapingFunctions/Shaping16"
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.uv.x = o.uv.x * 2 - 1;
                return o;
            }

            float Plot(float2 uv, float pct)
            {
                return smoothstep(pct - 0.02, pct, uv.y) - smoothstep(pct, pct + 0.02, uv.y);
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv * _Resolution;
                float y = 1 - pow(max(0, abs(uv.x) * 2 - 1), _a);
                float3 col = y / _Resolution;
                float pct = Plot(uv, y);
                return float4(lerp(col, pct * float3(0, 1, 0), pct), 1);
            }
            ENDHLSL
        }
    }
}
