Shader "MatCap/BaseMatCap/BaseMatCapWithNormalMap"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _MatCapTex ("MatCapTex", 2d) = "white" {}
        _NormalTex ("NormalTex", 2d) = "bump" {}
        _NormalRatio ("NormalRatio", range(0, 1)) = 0
        _Color ("Color", color) = (1, 1, 1, 1)
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
            float4 _Color;
            float _NormalRatio;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_MatCapTex); SAMPLER(sampler_MatCapTex);
            TEXTURE2D(_NormalTex); SAMPLER(sampler_NormalTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldTangent : TEXCOORD2;
                float3 worldBitangent : TEXCOORD3;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv.xy = v.uv;
                VertexNormalInputs vni = GetVertexNormalInputs(v.normal, v.tangent);
                o.worldNormal = vni.normalWS;
                o.worldTangent = vni.tangentWS;
                o.worldBitangent = vni.bitangentWS;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 viewNormal = TransformWorldToViewDir(i.worldNormal);
                float3 tangentNormal = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv));
                float3 worldNormal = normalize(mul(tangentNormal, float3x3(i.worldTangent, i.worldBitangent, i.worldNormal)));
                float3 viewTexNormal = TransformWorldToViewDir(worldNormal, true);
                viewNormal = lerp(viewNormal, viewTexNormal, _NormalRatio);
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                float4 matcap = SAMPLE_TEXTURE2D(_MatCapTex, sampler_MatCapTex, (viewNormal * 0.5 + 0.5).xy);
                return float4(col.rgb * matcap.rgb, col.a);
            }
            ENDHLSL
        }
    }
}
