Shader "MatCap/ImproveMatCap/ImproveMatCap"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _MatCapTex ("MatCapTex", 2d) = "white" {}
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
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_MatCapTex); SAMPLER(sampler_MatCapTex);

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
                float3 viewNormal : TEXCOORD1;
                float3 viewPos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
                o.viewNormal = normalize(o.viewNormal);
                o.viewPos = normalize(TransformWorldToView(TransformObjectToWorld(v.vertex.xyz)));
                return o;
            }

            float2 GetRWNMatcapUV(float3 viewNormal, float3 viewPos)
            {
                float3 posxnormal = cross(viewNormal, viewPos);
                float2 append_yx = float2(posxnormal.y, -posxnormal.x);
                float2 matcapuv = append_yx * 0.5 + 0.5;
                
                return matcapuv;
            }

            float4 frag (v2f i) : SV_Target
            {
				float2 matcapUV = GetRWNMatcapUV(i.viewNormal, i.viewPos);
                // float3 r = reflect(i.viewPos, i.viewNormal);
                // float m = 2.0 * sqrt(r.x * r.x + r.y * r.y + (r.z + 1) * (r.z + 1));
				// matcapUV = r.xy / m + 0.5;
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                float4 matcap = SAMPLE_TEXTURE2D(_MatCapTex, sampler_MatCapTex, matcapUV);
                return float4(col.rgb * matcap.rgb, col.a);
            }
            ENDHLSL
        }
    }
}
