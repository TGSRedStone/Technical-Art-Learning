Shader "ShaderToy/glowingMarblingBlack"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv =  (2.0 * i.uv) * 2;

                for(float i = 1.0; i < 10.0; i++){
                    uv.x += 0.6 / i * cos(i * 2.5* uv.y + _Time.y);
                    uv.y += 0.6 / i * cos(i * 1.5 * uv.x + _Time.y);
                }
                
                return float4(float3(0.1, 0.1, 0.1)/abs(sin(_Time.y-uv.y-uv.x)),1.0);
            }
            ENDHLSL
        }
    }
}
