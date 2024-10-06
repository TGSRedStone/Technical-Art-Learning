Shader "Shaders/BaseURPShader"
{
    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4x4 _WorldToShadow;
            float4x4 _inverseVP;

            TEXTURE2D(_CustomShadowMap);
            SAMPLER(sampler_CustomShadowMap);
            TEXTURE2D(_CustomDepthTexture);
            SAMPLER(sampler_CustomDepthTexture);

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

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            inline float UnityDecodeFloatRGBA(float4 enc)
            {
                float4 kDecodeDot = float4(1.0, 1 / 255.0, 1 / 65025.0, 1 / 16581375.0);
                return dot(enc, kDecodeDot);
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 encodeCamDepth = SAMPLE_TEXTURE2D(_CustomDepthTexture, sampler_CustomDepthTexture, i.uv);
                float camDepth = UnityDecodeFloatRGBA(encodeCamDepth);
                #if defined (SHADER_TARGET_GLSL)
                    CamDepth = CamDepth * 2 - 1;     // (0, 1)-->(-1, 1)
                #elif defined (UNITY_REVERSED_Z)
                camDepth = 1 - camDepth; // (0, 1)-->(1, 0)
                #endif

                float4 positionCS;
                positionCS.xy = i.uv * 2 - 1;
                positionCS.z = camDepth;
                positionCS.w = 1;

                float4 positionWS = mul(_inverseVP, positionCS);
                // positionWS /= positionWS.w;

                float4 shadowCoord = mul(_WorldToShadow, positionWS);
                shadowCoord.xyz /= shadowCoord.w;
                shadowCoord.xy = shadowCoord.xy * 0.5 + 0.5;

                float depth = shadowCoord.z;
                #if defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
                depth = depth * 0.5 + 0.5; //(-1, 1)-->(0, 1)
                #elif defined (UNITY_REVERSED_Z)
                depth = 1 - depth; //(1, 0)-->(0, 1)
                #endif
                float4 encodeLightDepth = SAMPLE_TEXTURE2D(_CustomShadowMap, sampler_CustomShadowMap, shadowCoord.xy);
                float lightDepth = UnityDecodeFloatRGBA(encodeLightDepth);

                float shadow = lightDepth < depth ? 0 : 1;
                return shadow;
            }
            ENDHLSL
        }
    }
}