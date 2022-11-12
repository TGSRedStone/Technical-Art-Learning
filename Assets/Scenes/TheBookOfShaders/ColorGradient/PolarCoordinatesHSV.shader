Shader "TheBookOfShaders/ColorGradient/PolarCoordinatesHSV"
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

            float3 hsb2rgb( in float3 c )
            {
                float3 rgb = clamp(abs(fmod(c.x * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0 );
                rgb = rgb * rgb * (3.0 - 2.0 * rgb);
                return c.z * lerp(float3(1.0, 1.0, 1.0), rgb, c.y);
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
                float2 uv = 0.5 - i.uv;
                float3 col = 0;
                float angle = atan2(uv.y, uv.x);
                float radius = length(uv) * 2;
                col = hsb2rgb(float3((angle/ TWO_PI) + 0.5, radius, 1.0));

                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}
