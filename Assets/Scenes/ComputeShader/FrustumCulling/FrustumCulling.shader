Shader "ComputeShader/FrustumCulling"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
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
            float4 _MainTex_ST;
            float4 _Color;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            StructuredBuffer<float4x4> positionBuffer;
            
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

            float3x3 Rotate(float angle)
            {
                float sin_radianY, cos_radianY;
                sincos(angle, sin_radianY, cos_radianY);
                float3x3 Rotate_Matrix_Z = float3x3(cos_radianY, 0, sin_radianY, 0, 1, 0, -sin_radianY, 0, cos_radianY);
                return  Rotate_Matrix_Z;
            }

            v2f vert (appdata v, uint instanceID : SV_InstanceID)
            {
                float4x4 data = positionBuffer[instanceID];
                
                float3 localPosition = v.vertex.xyz * data._11;
                float3 worldPosition = data._14_24_34 + localPosition;
                v2f o;
                o.vertex = mul(UNITY_MATRIX_VP, float4(worldPosition, 1.0f));;
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                return col;
            }
            ENDHLSL
        }
    }
}
