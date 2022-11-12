Shader "TheBookOfShaders/ColorGradient"
{
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
                return smoothstep( pct - 0.01, pct, st.y) - smoothstep( pct, pct + 0.01, st.y);
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
                float2 uv = i.uv;
                float3 colorA = float3(0.149,0.141,0.912);
                float3 colorB = float3(1.000,0.833,0.224);
                float3 col = 0;
                float3 pct = 0;
                
                pct.r = smoothstep(0.0, 1.0, uv.x);
                pct.g = sin(uv.x * PI);
                pct.b = pow(uv.x, 0.5);
            
                col = lerp(colorA, colorB, pct);
            
                // Plot transition lines for each channel
                col = lerp(col, float3(1.0, 0.0, 0.0), plot(uv, pct.r));
                col = lerp(col, float3(0.0, 1.0, 0.0), plot(uv, pct.g));
                col = lerp(col, float3(0.0, 0.0, 1.0), plot(uv, pct.b));
                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}
