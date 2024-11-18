Shader "Shaders/BaseURPShader"
{
    Properties
    {
        _NormalMap1 ("NormalMap1", 2d) = "bump" {}
        _NormalMap2 ("NormalMap2", 2d) = "bump" {}
        [KeywordEnum(Linear, PD, UDN, WhiteOut, RNM)] _KEYWORD0("BlendMode", float) = 0
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
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_local  _KEYWORD0_Linear _KEYWORD0_PD _KEYWORD0_UDN _KEYWORD0_WhiteOut _KEYWORD0_RNM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            CBUFFER_END

            TEXTURE2D(_NormalMap1);
            SAMPLER(sampler_NormalMap2);
            TEXTURE2D(_NormalMap2);
            SAMPLER(sampler_NormalMap1);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS:NORMAL;
                float4 tangentOS:TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionOS : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                float4 TW1:TEXCOORD1;
                float4 TW2:TEXCOORD2;
                float4 TW3:TEXCOORD3;
            };

            Varyings Vertex(Attributes input)
            {
                Varyings output;
                output.positionOS = TransformObjectToHClip(input.positionOS.xyz);
                output.texcoord = input.texcoord;

                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float3 tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
                float3 binormalWS = cross(normalWS, tangentWS) * input.tangentOS.w;

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);

                output.TW1 = float4(tangentWS.x, binormalWS.x, normalWS.x, positionWS.x);
                output.TW2 = float4(tangentWS.y, binormalWS.y, normalWS.y, positionWS.y);
                output.TW3 = float4(tangentWS.z, binormalWS.z, normalWS.z, positionWS.z);
                return output;
            }

            float3 NormalBlend_Linear(float3 A, float3 B)
            {
                float3 r = A + B;
                return normalize(r);
            }

            float3 NormalBlend_PartialDerivative(float3 A, float3 B)
            {
                float3 r = A.xyz * B.z + float3(B.xy, 0) * A.z;
                return normalize(r);
            }

            float3 NormalBlend_UDN(float3 A, float3 B)
            {
                float3 r = float3(A.xy + B.xy, A.z);
                return normalize(r);
            }

            float3 NormalBlend_WhiteOut(float3 A, float3 B)
            {
                float3 r = float3(A.xy + B.xy, A.z * B.z);
                return normalize(r);
            }

            float3 NormalBlend_RNM(float3 A, float3 B)
            {
                float3 t = A.xyz + float3(0.0, 0.0, 1.0);
                float3 u = B.xyz * float3(-1.0, -1.0, 1.0);
                float3 r = t * dot(t, u) / t.z - u;
                return normalize(r);
            }

            float3 NormalBlending(float3 A, float3 B)
            {
                #if defined(_KEYWORD0_Linear)
                return NormalBlend_Linear(A, B);
                
                #elif defined(_KEYWORD0_PD)
                return NormalBlend_PartialDerivative(A, B);
                
                #elif defined(_KEYWORD0_UDN)
                return NormalBlend_UDN(A, B);
                
                #elif defined(_KEYWORD0_WhiteOut)
                return NormalBlend_WhiteOut(A, B);
                
                #elif defined(_KEYWORD0_RNM)
                return NormalBlend_RNM(A, B);
                
                #else
                return 0;
                
                #endif
            }

            float4 Fragment(Varyings input) : SV_Target
            {
                float3x3 TW = float3x3(input.TW1.xyz, input.TW2.xyz, input.TW3.xyz);
                float3 normalATS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap1, sampler_NormalMap1, input.texcoord));
                float3 normalBTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap2, sampler_NormalMap2, input.texcoord));

                float3 finalNormalTS = NormalBlending(normalATS, normalBTS);
                float3 finalNormalWS = mul(TW, finalNormalTS);

                Light light = GetMainLight();
                half3 lightDirWS = TransformObjectToWorldDir(light.direction);

                float3 diffuse = float3(0.1, 0.1, 0.1) * saturate(dot(finalNormalWS, lightDirWS));
                return float4(diffuse, 1);
            }
            ENDHLSL
        }
    }
}