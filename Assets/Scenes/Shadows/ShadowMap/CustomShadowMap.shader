Shader "Shadows/ShadowMap/CustomShadowMap"
{
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _SHADOWTYPE_HARDSHADOW _SHADOWTYPE_PCF

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _ShadowMapTexture_TexelSize;
            float _ShadowStrength;
            float _Bias;
            float4x4 _WorldToShadow;
            CBUFFER_END

            TEXTURE2D(_ShadowMapTexture); SAMPLER(sampler_ShadowMapTexture);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 shadowCoord : TEXCOORD1;
                float4 worldPos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.shadowCoord = mul(_WorldToShadow, o.worldPos);
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

            float HardShadow (float depth, float2 shadowCoord)
            {
                float4 orignDepth = SAMPLE_TEXTURE2D(_ShadowMapTexture, sampler_ShadowMapTexture, shadowCoord);
                return (orignDepth + _Bias) < depth ? _ShadowStrength : 1;
            }

            float PCF (float depth, float2 shadowCoord, int filterSize)
            {
                float shadow = 0.0;
                int halfSize = max(0, (filterSize - 1) / 2);
                for(int i = -halfSize; i <= halfSize; ++i)
                {
                    for(int j = -halfSize; j < halfSize; ++j)
                    {
                        float4 orignDepth = SAMPLE_TEXTURE2D(_ShadowMapTexture, sampler_ShadowMapTexture, shadowCoord + float2(i, j) * _ShadowMapTexture_TexelSize.xy);
                        shadow += (orignDepth + _Bias) < depth ? _ShadowStrength : 1;
                    }
                }
                return shadow / (filterSize * filterSize);
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 shadowCoord = i.shadowCoord.xy / i.shadowCoord.w;
                shadowCoord = shadowCoord * 0.5 + 0.5;
                
                float depth = i.shadowCoord.z / i.shadowCoord.w;
                #if defined(SHADER_TARGET_GLSL)
                    depth = depth * 0.5 + 0.5;    
                #elif defined(UNITY_REVERSED_Z)
                    depth = 1 - depth;      
                #endif

                float shadow = 1;

                #if defined(_SHADOWTYPE_HARDSHADOW)
                    shadow = HardShadow(depth, shadowCoord);
                #elif defined(_SHADOWTYPE_PCF)
                    shadow = PCF(depth, shadowCoord, 5);
                #endif
                
                return shadow;
            }
            ENDHLSL
        }
    }
}
