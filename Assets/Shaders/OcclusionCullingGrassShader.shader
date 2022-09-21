Shader "Grass/OcclusionCullingGrass"
{
    Properties
    {
        _Color ("Color", color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            CBUFFER_END

            StructuredBuffer<float4x4> positionBuffer;

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
                float3 normalWS : NORMAL;
            };

            v2f vert (appdata v, uint instanceID : SV_InstanceID)
            {
                v2f o;
                float4x4 data = positionBuffer[instanceID];
                
                v.vertex.xz += sin(_Time.y * 2) / 50 * smoothstep(0, 0.2, v.vertex.y);
                float3 localPosition = v.vertex.xyz * data._11;
                float3 worldPosition = data._14_24_34 + localPosition;
                o.vertex = mul(UNITY_MATRIX_VP, float4(worldPosition, 1.0f));;
                o.uv = v.uv;
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.normalWS);
                float3 worldLight = normalize(_MainLightPosition.xyz);
                float NdotL = max(0.0, dot(worldNormal, worldLight));
                float3 diffuse = lerp(_Color.rgb, _MainLightColor.rgb * _Color.rgb, NdotL);
                
                return float4(diffuse, 1);
            }
            ENDHLSL
        }
    }
}
