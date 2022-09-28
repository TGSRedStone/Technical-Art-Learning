Shader "Sci-Fi/Shield/DotsShield"
{
    Properties
    {
        _NoiseAndOutLineTex("NoiseAndOutLineTex", 2d) = "white" {}
        [HDR]_Color ("Color", color) = (1, 1, 1, 1)
        [HDR]_OutLineColor ("OutLineColor", color) = (1, 1, 1, 1)
        
        [Space(20)]
        _DotSize("DotSize", float) = 1
        _DotsTilesTilingAndOffset("DotsTilesTilingAndOffset", vector) = (5, 5, 1, 1)
        
        [Space(20)]
        _RadialScale("RadialScale", float) = 1
        _RadialPow("RadialPow", float) = 1
        _FlowNoiseTiling("FlowNoiseTiling", float) = 1
        _FlowSpeed("FlowSpeed", float) = 1
        
    }
    
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        blend one one

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float4 _OutLineColor;
            float4 _DotsTilesTilingAndOffset;
            float _DotSize;
            float _RadialScale;
            float _RadialPow;
            float _FlowNoiseTiling;
            float _FlowSpeed;
            CBUFFER_END

            TEXTURE2D(_NoiseAndOutLineTex); SAMPLER(sampler_NoiseAndOutLineTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float3 worldPos : TEXCOORF1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            float Ellipse(float2 uv)
            {
                float d = length((uv * 2 - 1) / _DotSize);
                return saturate((1 - d) / fwidth(d));
            }

            float2 DotsUV(float2 uv)
            {
                float2 dotsUV = uv * _DotsTilesTilingAndOffset.xy;
                float xTiles = step(1, fmod(dotsUV.y, 2)) * _DotsTilesTilingAndOffset.z + dotsUV.x;
                float yTiles = step(1, fmod(dotsUV.x, 2)) * _DotsTilesTilingAndOffset.w + dotsUV.y;
                return frac(float2(xTiles, yTiles));
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 delta = i.uv - float2(0.5, 0.5);
                float radius = length(delta) * 2 * _RadialScale;
                radius = pow(abs(radius), _RadialPow);
                float2 dotsUV = DotsUV(i.uv);
                float Dots = Ellipse(dotsUV);
                float outLine = SAMPLE_TEXTURE2D(_NoiseAndOutLineTex, sampler_NoiseAndOutLineTex, i.uv).b;
                float noise = SAMPLE_TEXTURE2D(_NoiseAndOutLineTex, sampler_NoiseAndOutLineTex, i.uv).r;
                float flowNoise = SAMPLE_TEXTURE2D(_NoiseAndOutLineTex, sampler_NoiseAndOutLineTex, float2(i.uv.x * _FlowNoiseTiling, i.uv.y * _FlowNoiseTiling + _Time.y / _FlowSpeed)).r;
                return (Dots * noise + flowNoise) * radius * _Color + outLine * _OutLineColor;
            }
            ENDHLSL
        }
    }
}
