Shader "Shaders/BaseURPShader"
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
            float _ShadowStrength;
            float _ShadowBias;
            float4x4 _WorldToShadow;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_ScreenSpaceShadowTexture); SAMPLER(sampler_ScreenSpaceShadowTexture);
            TEXTURE2D(_CustomShadowMap); SAMPLER(sampler_CustomShadowMap);
            TEXTURE2D(_CustomDepthTexture); SAMPLER(sampler_CustomDepthTexture);
            

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 shadowCoord : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.shadowCoord = mul(_WorldToShadow, worldPos);
                o.screenPos = o.vertex;
                return o;
            }

            inline float DecodeFloatRGBA(float4 enc) 
            {
                int ex = (uint)(enc.x * 255);
                int ey = (uint)(enc.y * 255);
                int ez = (uint)(enc.z * 255);
                int ew = (uint)(enc.w * 255);
                float v = (ex << 24) + (ey << 16) + (ez << 8) + ew;
                return v / (256.0f * 256.0f * 256.0f * 256.0f);
            }

            inline float UnityDecodeFloatRGBA( float4 enc )
            {
                float4 kDecodeDot = float4(1.0, 1/255.0, 1/65025.0, 1/16581375.0);
                return dot( enc, kDecodeDot );
            }

            // float HardShadow (float depth, float2 shadowCoord)
            // {
            //     float4 EncodeClosestDepth = SAMPLE_TEXTURE2D(_CustomShadowMap, sampler_CustomShadowMap, shadowCoord);
            //     float DecodeClosestDepth = UnityDecodeFloatRGBA(EncodeClosestDepth);
            //     return (DecodeClosestDepth + _ShadowBias) < depth ? _ShadowStrength : 1.0;
            // }

            float4 frag (v2f i) : SV_Target
            {
                float3 shadowCoord = i.shadowCoord.xyz / i.shadowCoord.w;
                shadowCoord.xy = shadowCoord.xy * 0.5 + 0.5;
                float depth = i.shadowCoord.z;
                #if defined(SHADER_TARGET_GLSL)
                    depth = depth * 0.5 + 0.5;    
                #elif defined(UNITY_REVERSED_Z)
                    depth = 1.0 - depth;
                #endif
                // float shadow = HardShadow(depth, shadowCoord.xy);
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                i.screenPos.xy = i.screenPos.xy / i.screenPos.w;
                float2 screenUV = i.screenPos.xy * 0.5 + 0.5;
                float4 shadow = SAMPLE_TEXTURE2D(_ScreenSpaceShadowTexture, sampler_ScreenSpaceShadowTexture, screenUV);
                float4 shadow1 = SAMPLE_TEXTURE2D(_CustomShadowMap, sampler_CustomShadowMap, screenUV);
                float4 shadow2 = SAMPLE_TEXTURE2D(_CustomDepthTexture, sampler_CustomDepthTexture, screenUV);
                return col * shadow * shadow1 * shadow2;
            }
            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "LightMode" = "CustomShadowCaster"
            }
        }
        
        Pass
        {
            Tags
            {
                "LightMode" = "CustomDepthPass"
            }
        }
    }
}
