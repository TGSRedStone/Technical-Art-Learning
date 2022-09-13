Shader "Sci-Fi/Shield/DotsShield"
{
    Properties
    {
        _NoiseTex ("NoiseTex", 2d) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
        _Size("Size", float) = 1
        _RadialScale("RadialScale", float) = 1
        _RadialPow("RadialPow", float) = 1
        
        _TilesTilingAndOffset("TilesTilingAndOffset", vector) = (5, 5, 1, 1)
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
            float4 _MainTex_ST;
            float4 _Color;
            float4 _TilesTilingAndOffset;
            float _Size;
            float _RadialScale;
            float _RadialPow;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

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

            float Ellipse(float2 UV)
            {
                float d = length((UV * 2 - 1) / _Size);
                return saturate((1 - d) / fwidth(d));
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 delta = i.uv - float2(0.5, 0.5);
                float radius = length(delta) * 2 * _RadialScale;
                radius = pow(radius, _RadialPow);
                float2 uv = i.uv * _TilesTilingAndOffset.xy;
                float xTiles = step(1, fmod(uv.y, 2)) * _TilesTilingAndOffset.z + uv.x;
                float yTiles = step(1, fmod(uv.x, 2)) * _TilesTilingAndOffset.w + uv.y;
                uv = frac(float2(xTiles, yTiles));
                float Dots = Ellipse(uv);
                return Dots * radius;
            }
            ENDHLSL
        }
    }
}
