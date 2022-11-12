Shader "TheBookOfShaders/Shapes/CircularGraphics"
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

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

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

            float CircularInOut(float t) {
              return t < 0.5
                ? 0.5 * (1.0 - sqrt(1.0 - 4.0 * t * t))
                : 0.5 * (sqrt((3.0 - 2.0 * t) * (2.0 * t - 1.0)) + 1.0);
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
                float pct = 0;
                // pct = pow(distance(uv, 0.4),distance(uv, 0.6));
                // pct = distance(uv, 0.4) + distance(uv, 0.6);
                // pct = distance(uv, 0.4) * distance(uv, 0.6);
                pct = min(distance(uv, 0.4), distance(uv, 0.6)) * CircularInOut(abs(frac(_Time.y) * 2 - 1));
                // pct = max(distance(uv, 0.4),distance(uv, 0.6));
                // pct = pow(distance(uv, 0.4),distance(uv, 0.6));
                
                return pct;
            }
            ENDHLSL
        }
    }
}
