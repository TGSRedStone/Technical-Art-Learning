Shader "Shadows/ShadowMap/DepthTexture"
{
    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float _ShadowNormalBias;
            float _ShadowBias;

            struct appdata
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
            };

            // float3 ApplyShadowBias(float3 positionWS, float3 normalWS, float3 lightDirection)
            // {
            //     float invNdotL = 1.0 - saturate(dot(lightDirection, normalWS));
            //     float scale = invNdotL * _ShadowBias;
            //
            //     // normal bias is negative since we want to apply an inset normal offset
            //     positionWS = lightDirection * _ShadowBias.xxx + positionWS;
            //     // positionWS = normalWS * scale.xxx + positionWS;
            //     return positionWS;
            // }
            //
            // float4 GetShadowPositionHClip(appdata input)
            // {
            //     float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
            //     float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
            //
            //     // float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, normalize(_MainLightPosition.xyz)));
            //     float4 positionCS = TransformWorldToHClip(positionWS);
            //
            //     #if UNITY_REVERSED_Z
            //     positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
            //     #else
            //     positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
            //     #endif
            //
            //     return positionCS;
            // }

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(input);
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                return o;
            }

            inline float4 EncodeFloatRGBA(float v)
            {
                float vi = (uint)(v * (256.0f * 256.0f * 256.0f * 256.0f));
                float ex = (int)(vi / (256 * 256 * 256) % 256);
                float ey = (int)((vi / (256 * 256)) % 256);
                float ez = (int)((vi / (256)) % 256);
                float ew = (int)(vi % 256);
                float4 e = float4(ex / 255.0f, ey / 255.0f, ez / 255.0f, ew / 255.0f);
                return e;
            }

            inline float4 UnityEncodeFloatRGBA(float v)
            {
                float4 kEncodeMul = float4(1.0, 255.0, 65025.0, 16581375.0);
                float kEncodeBit = 1.0 / 255.0;
                float4 enc = kEncodeMul * v;
                enc = frac(enc);
                enc -= enc.yzww * kEncodeBit;
                return enc;
            }

            float4 frag(v2f i) : SV_Target
            {
                float depth = i.positionCS.z / i.positionCS.w;

                #if defined(SHADER_TARGET_GLSL)
                    depth = depth * 0.5 + 0.5;
                #elif defined(UNITY_REVERSED_Z)
                depth = 1.0 - depth;
                #endif
                // return depth;
                return UnityEncodeFloatRGBA(depth);
            }
            ENDHLSL
        }
    }
}