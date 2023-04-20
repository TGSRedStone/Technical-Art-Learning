Shader "Else/Tessellation"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
        
        _WireframeColor ("Wireframe Color", color) = (0, 0, 0)
        _WireframeSmoothing ("Wireframe Smoothing", range(0, 10)) = 1
        _WireframeThickness ("Wireframe Thickness", range(0, 10)) = 1
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geometry

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _Color;
            float4 _WireframeColor;
            float _WireframeSmoothing;
            float _WireframeThickness;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2g
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            struct g2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float2 barycentricCoordinators : TEXCOORD1;
            };

            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            [maxvertexcount(3)]
            void geometry(triangle v2g i[3], inout TriangleStream<g2f> stream)
            {
                g2f g0, g1, g2;
                g0.uv = i[0].uv;
                g1.uv = i[1].uv;
                g2.uv = i[2].uv;
                g0.vertex = i[0].vertex;
                g1.vertex = i[1].vertex;
                g2.vertex = i[2].vertex;
                g0.barycentricCoordinators = float2(1, 0);
                g1.barycentricCoordinators = float2(0, 1);
                g2.barycentricCoordinators = float2(0, 0);
                stream.Append(g0);
                stream.Append(g1);
                stream.Append(g2);
            }

            float4 frag (g2f i) : SV_Target
            {
                float3 barys;
                barys.xy = i.barycentricCoordinators;
                barys.z = 1 - barys.x - barys.y;
                float3 deltas = fwidth(barys);
                float3 smoothing = deltas * _WireframeSmoothing;
                float3 thickness = deltas * _WireframeThickness;
                barys = smoothstep(thickness, thickness + smoothing, barys);
                float minBary = min(barys.x, min(barys.y, barys.z));
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                return lerp(_WireframeColor, col, minBary);
            }
            ENDHLSL
        }
    }
}
