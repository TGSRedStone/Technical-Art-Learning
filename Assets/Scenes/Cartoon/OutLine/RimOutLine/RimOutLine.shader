//reference : https://alexanderameye.github.io/notes/rendering-outlines/
Shader "Cartoon/OutLine/RimOutLine"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _RimColor ("RimColor", color) = (1, 1, 1, 1)
        _Color ("Color", color) = (1, 1, 1, 1)
        _Power ("Power", float) = 5
        _OutLineWidth ("OutLineWidth", float) = 1
        _OutLineSoftness ("OutLineSoftness", float) = 1
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
            float4 _MainTex_ST;
            float4 _RimColor;
            float4 _Color;
            float _Power;
            float _OutLineWidth;
            float _OutLineSoftness;
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
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldViewDir = normalize(GetWorldSpaceViewDir(i.worldPos));
                float NDotV = saturate(dot(worldNormal, worldViewDir)) + 1e-5f;
                float edge1 = 1 - _OutLineWidth;
                float edge2 = edge1 + _OutLineSoftness;
                float rim = pow(1 - NDotV, _Power);
                rim = lerp(1, smoothstep(edge1, edge2, rim), step(0, edge1));
                float3 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb * _Color.rgb;
                return float4(rim * _RimColor + col, 1);
            }
            ENDHLSL
        }
    }
}
