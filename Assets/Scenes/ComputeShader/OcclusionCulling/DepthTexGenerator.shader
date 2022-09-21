Shader "DepthTex/DepthTexGenerator"
{
    Properties
    {
        [HideInInspector] _MainTex("Previous Mipmap", 2D) = "black" {}
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            float4 _MainTex_TexelSize;

            float CalculatorMipmapDepth(float2 uv)
            {
                float4 depth;
                float offset = _MainTex_TexelSize.x / 2;
                depth.x = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).r;
                depth.y = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(0, offset)).r;
                depth.z = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(offset, 0)).r;
                depth.w = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(offset, offset)).r;
#if defined(UNITY_REVERSED_Z)
                return min(min(depth.x, depth.y), min(depth.z, depth.w));
#else
                return max(max(depth.x, depth.y), max(depth.z, depth.w));
#endif
            }

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
                float depth = CalculatorMipmapDepth(i.uv);
                return float4(depth, 0, 0, 1.0f);
            }
            ENDHLSL
        }
    }
}
