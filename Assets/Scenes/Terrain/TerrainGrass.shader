Shader "Terrain/TerrainGrass"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _BaseColorTex ("BaseColorTex", 2d) = "white" {}
        _GroundColor ("_GroundColor", color) = (0.5, 0.5, 0.5)
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"
        }
        ZWrite On
        ZTest On
        Cull Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColorTex_ST;

                half3 _GroundColor;

                StructuredBuffer<float4x4> _AllInstancesTransformBuffer;
                StructuredBuffer<uint> _OnlyInstanceVisibleIDBuffer;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_BaseColorTex);
            SAMPLER(sampler_BaseColorTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half3 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            half3 ApplySingleDirectLight(Light light, half3 N, half3 V, half3 albedo, half positionOSY)
            {
                half3 H = normalize(light.direction + V);

                //direct diffuse 
                half directDiffuse = dot(N, light.direction) * 0.5 + 0.5; //half lambert, to fake grass SSS

                //direct specular
                float directSpecular = saturate(dot(N, H));
                //pow(directSpecular,8)
                directSpecular *= directSpecular;
                directSpecular *= directSpecular;
                directSpecular *= directSpecular;
                //directSpecular *= directSpecular; //enable this line = change to pow(directSpecular,16)

                //add direct directSpecular to result
                directSpecular *= 0.1 * positionOSY;
                //only apply directSpecular to grass's top area, to simulate grass AO

                half3 lighting = light.color * (light.shadowAttenuation * light.distanceAttenuation);
                half3 result = (albedo * directDiffuse + directSpecular) * lighting;
                return result;
            }

            Varyings vert(Attributes input, uint instanceID : SV_InstanceID)
            {
                Varyings output;

                float4x4 grassPositionWS = _AllInstancesTransformBuffer[_OnlyInstanceVisibleIDBuffer[
                    instanceID]];
                float3 positionWS = mul(grassPositionWS, input.positionOS);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float3 viewDirWS = normalize(GetWorldSpaceViewDir(positionWS));
                output.positionCS = TransformWorldToHClip(positionWS);
                output.uv = input.uv;

                float positionOSY = input.positionOS.y * grassPositionWS._22;

                Light mainLight;
                #if _MAIN_LIGHT_SHADOWS
                mainLight = GetMainLight(TransformWorldToShadowCoord(positionWS));
                #else
                mainLight = GetMainLight();
                #endif

                half3 baseColor = SAMPLE_TEXTURE2D_X_LOD(_BaseColorTex, sampler_BaseColorTex,
                                                         float2(TRANSFORM_TEX(positionWS.xz,
                                                             _BaseColorTex)), 0);
                half3 albedo = lerp(_GroundColor, baseColor, positionOSY);

                half3 lightingResult = SampleSH(0) * albedo;
                lightingResult += ApplySingleDirectLight(mainLight, normalWS, viewDirWS, albedo, positionOSY);

                output.color = lightingResult;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                clip(col.a - 0.1);

                return half4(input.color, 1);
            }
            ENDHLSL
        }
    }
}