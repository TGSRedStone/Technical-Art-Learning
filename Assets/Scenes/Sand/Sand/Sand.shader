Shader "Sand/Sand"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _NormalMap ("NormalMap", 2d) = "bump" {}
        _DetailNormalMap ("DetailNormalMap", 2d) = "bump" {}
        _Color ("Color", color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Assets/Shaders/PBRInclude.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _NormalMap_ST;
            float4 _DetailNormalMap_ST;
            float4 _Color;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_DetailNormalMap);
            SAMPLER(sampler_DetailNormalMap);

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldTangentDir : TEXCOORD2;
                float3 worldBitangentDir : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
            };

            float3 NormalBlend_Reoriented(float3 A, float3 B)
            {
                float3 t = A.xyz + float3(0.0, 0.0, 1.0);
                float3 u = B.xyz * float3(-1.0, -1.0, 1.0);
                return (t / t.z) * dot(t, u) - u;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldTangentDir = normalize(TransformObjectToWorld(v.tangent.xyz));
                o.worldBitangentDir = normalize(cross(o.worldNormal, o.worldTangentDir) * v.tangent.w);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 worldPos = i.worldPos;
                float3 worldViewVector = GetWorldSpaceViewDir(worldPos);
                float3 worldViewDir = normalize(worldViewVector);
                float3x3 tangentTransform = float3x3(i.worldTangentDir, i.worldBitangentDir, i.worldNormal);

                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv * 20);
                float3 normalMap = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv * 20));
                float3 detailNormalMap = UnpackNormal(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, i.uv * 400));
                float3 finiNormalMap = NormalBlend_Reoriented(normalMap, detailNormalMap);
                float3 worldNormalMap = mul(finiNormalMap, tangentTransform);

                float smooth = 1 - saturate(pow(detailNormalMap.r * 0.5 + 0.5, 0.2));
                
                float4 result = PBR(worldNormalMap, worldViewDir, albedo, smooth, 0.5);
                return result;
            }
            ENDHLSL
        }
    }
}