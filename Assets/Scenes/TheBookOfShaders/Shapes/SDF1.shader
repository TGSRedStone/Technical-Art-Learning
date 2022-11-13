Shader "TheBookOfShaders/Shapes/SDF1"
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
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv * _Resolution;
                float3 d = 0.0;
                uv = uv * 2 - 1;
                d = length(abs(uv) - 0.5);
                d = length(min(abs(uv)- 0.3, 0.0));
                d = length(max(abs(uv)- 0.3, 0.0));

                return float4(float3(frac(d * _a * 10.0)), 1.0);
                // return float4(float3(step(0.3, d)), 1.0);
                // return float4(float3(step(0.3, d) * step(d, 0.4)), 1.0);
                // return float4(float3(smoothstep(0.3, 0.4, d) * smoothstep(0.6, 0.5, d)) ,1.0);
            }
            ENDHLSL
        }
    }
}
