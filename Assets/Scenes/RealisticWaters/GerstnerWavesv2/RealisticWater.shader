Shader "Water/RealisticWater"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DetailNormal ("DetailNormal", 2D) = "white" {}
        _Foam ("Foam", 2D) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
        _TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
        _MaxTessDistance("Max Tess Distance", Range(1, 1000)) = 20
        _MinTessDistance("Min Tess Distance", Range(1, 32)) = 1
        _MaxWaveHeight ("MaxWaveHeight", float) = 1
        _MaxDepth ("MaxDepth", float) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" "LightMode"="UniversalForward"
        }

        Pass
        {
            Cull Off
            HLSLPROGRAM
            #pragma target 4.6
            #pragma vertex TessVert
            #pragma hull Hull
            #pragma domain Domain
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "GenerateWave.hlsl"

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Color;
                float4 _WireframeColor;
                float _TessellationUniform;
                float _MaxTessDistance;
                float _MinTessDistance;
                float _MaxWaveHeight;
                float _MaxDepth;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_DetailNormal);
            SAMPLER(sampler_DetailNormal);
            TEXTURE2D(_Foam);
            SAMPLER(sampler_Foam);
            TEXTURE2D(_AbsorptionScatteringRamp);
            SAMPLER(sampler_AbsorptionScatteringRamp);
            TEXTURE2D(_PlanarReflectionTexture);
            SAMPLER(sampler_PlanarReflectionTexture);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            struct Appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct V2f
            {
                float4 clipPos : SV_POSITION;
                float3 normalWS : NORMAL;
                float4 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
                float3 depthData : TEXCOORD4;
            };

            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            struct TessInput
            {
                float4 positionOS : INTERNALTESSPOS;
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            half3 Scattering(half depth)
            {
                return SAMPLE_TEXTURE2D(_AbsorptionScatteringRamp, sampler_AbsorptionScatteringRamp,
                                        half2(depth, 0.9h)).rgb;
            }

            half3 Absorption(half depth)
            {
                return SAMPLE_TEXTURE2D(_AbsorptionScatteringRamp, sampler_AbsorptionScatteringRamp,
                                        half2(depth, 0.0h)).rgb;
            }

            float3 DepthData(float3 positionWS, float3 wavePosition)
            {
                float3 viewPos = TransformWorldToView(positionWS);
                float x = length(viewPos / viewPos.z); // distance to surface
                float y = length(GetCameraPositionWS().xyz - positionWS); // local position in camera space
                float z = wavePosition.y / _MaxWaveHeight * 0.5 + 0.5;
                return float3(x, y, z);
            }

            half3 SamplePlanarReflections(half3 normalWS, half2 screenUV, half roughness)
            {
                half3 reflection = 0;

                half2 reflectionUV = screenUV + normalWS.zx * half2(0.02, 0.15);
                reflection += SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, sampler_PlanarReflectionTexture,
                                                   reflectionUV, 6 * roughness).rgb; //planar reflection

                return reflection;
            }

            half3 Refraction(half2 distortion, half depth, real depthMulti)
            {
                half3 output = SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, distortion,
                                                    depth * 0.25).rgb;
                output *= Absorption((depth) * depthMulti);
                return output;
            }

            half2 DistortionUVs(half depth, float3 normalWS)
            {
                half3 viewNormal = mul((float3x3)GetWorldToHClipMatrix(), -normalWS).xyz;

                return viewNormal.xz * saturate((depth) * 0.005);
            }

            half3 SampleNormal(float2 uv, TEXTURE2D_PARAM(bumpMap, sampler_bumpMap), half scale = 1.0h)
            {
                half4 n = SAMPLE_TEXTURE2D(bumpMap, sampler_bumpMap, uv);
                #if BUMP_SCALE_NOT_SUPPORTED
                    return UnpackNormal(n);
                #else
                    return UnpackNormalScale(n, scale);
                #endif
            }

            V2f Vert(Appdata v)
            {
                V2f o;
                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);

                WaveStruct waves;
                waves.normal = 0;
                waves.position = 0;
                half waveCountMulti = 1.0 / _WaveCount;
                for (int i = 0; i < _WaveCount; i++)
                {
                    Wave w = _WaveDataBuffer[i];
                    WaveStruct wave = GerstnerWave(positionWS.xz, waveCountMulti, w.amplitude, w.direction,
                                                   w.wavelength, w.omni, w.origin);
                    waves.position += wave.position;
                    waves.normal += wave.normal;
                }

                positionWS += waves.position;

                o.clipPos = TransformWorldToHClip(positionWS);
                o.uv.xy = positionWS.xz * 0.2 + _Time.y * 0.05;
                o.uv.zw = positionWS.xz * 0.5 + _Time.y * 0.1;
                o.normalWS = normalize(waves.normal);
                o.shadowCoord = ComputeScreenPos(o.clipPos);
                o.positionWS = positionWS;
                o.viewDir = SafeNormalize(_WorldSpaceCameraPos - positionWS);
                o.depthData = DepthData(positionWS, waves.position);
                return o;
            }

            //所有的变量类型需要根据用途优化
            float4 Frag(V2f i) : SV_Target
            {
                Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                float3 screenUV = i.shadowCoord.xyz / i.shadowCoord.w;

                float rawDepth = SampleSceneDepth(i.shadowCoord.xy / i.shadowCoord.w);
                float depth = LinearEyeDepth(rawDepth, _ZBufferParams) * i.depthData.x - i.depthData.y;

                float3 detailNormal1 = SampleNormal(i.uv.xy, TEXTURE2D_ARGS(_DetailNormal, sampler_DetailNormal));
                float3 detailNormal2 = SampleNormal(i.uv.zw, TEXTURE2D_ARGS(_DetailNormal, sampler_DetailNormal));
                float3 detailNormal = (detailNormal1 + detailNormal2 * 0.5) * saturate(depth * 0.25 + 0.25);

                i.normalWS += float3(detailNormal.x, 0, detailNormal.y) * 0.5;
                i.normalWS = normalize(i.normalWS);

                float3 GI = SampleSH(i.normalWS);

                float3 directLighting = dot(light.direction, half3(0, 1, 0)) * light.color;
                directLighting += saturate(pow(dot(i.viewDir, -light.direction) * i.depthData.z, 3)) * 5 *
                    light.color;
                float3 sss = directLighting + GI;
                float depthMulti = 1 / _MaxDepth;
                sss *= Scattering(depth * depthMulti);

                //浮沫的实现非常简陋，之后细化
                float foam = SAMPLE_TEXTURE2D(_Foam, sampler_Foam, i.uv.zw).r;
                float foamMask = saturate((1 - depth) * foam);
                float3 foamCol = foamMask * (light.shadowAttenuation * light.color + GI);

                float fresnel = saturate(pow(1.0 - dot(i.normalWS, i.viewDir), 5));;

                BRDFData brdfData;
                float alpha = 1;
                InitializeBRDFData(half3(0, 0, 0), 0, half3(1, 1, 1), 0.95, alpha, brdfData);
                float3 spec = DirectBDRF(brdfData, i.normalWS, light.direction, i.viewDir) * light.color;

                #ifdef _ADDITIONAL_LIGHTS
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, i.positionWS);
                    spec += LightingPhysicallyBased(brdfData, light, i.normalWS, i.viewDir);
                    sss += light.distanceAttenuation * light.color;
                }
                #endif

                float3 reflection = SamplePlanarReflections(i.normalWS, screenUV.xy, 0.0);

                float2 distortion = DistortionUVs(depth.x, i.normalWS);
                distortion = screenUV.xy + distortion;
                float3 refraction = Refraction(distortion, depth, depthMulti);

                float3 composite = lerp(lerp(refraction, reflection, fresnel) + sss + spec, foamCol, foamMask);
                return float4(composite, 1);
            }

            TessInput TessVert(Appdata v)
            {
                TessInput o;
                o.positionOS = v.positionOS;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                return o;
            }

            float CalcDistanceTessFactor(float4 positionOS, float minDist, float maxDist, float tess)
            {
                float3 positionWS = TransformObjectToWorld(positionOS.xyz);
                float dist = distance(positionWS, GetCameraPositionWS());
                float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
                return (f);
            }

            TessellationFactors PatchConstantFunction(InputPatch<TessInput, 3> patch)
            {
                TessellationFactors f;

                float edge0 = CalcDistanceTessFactor(patch[0].positionOS, _MinTessDistance, _MaxTessDistance,
                                                     _TessellationUniform);
                float edge1 = CalcDistanceTessFactor(patch[1].positionOS, _MinTessDistance, _MaxTessDistance,
                                                     _TessellationUniform);
                float edge2 = CalcDistanceTessFactor(patch[2].positionOS, _MinTessDistance, _MaxTessDistance,
                                                     _TessellationUniform);

                f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
                return f;
            }

            [domain("tri")]
            [outputcontrolpoints(3)]
            [outputtopology("triangle_cw")]
            [partitioning("fractional_odd")]
            [patchconstantfunc("PatchConstantFunction")]
            TessInput Hull(InputPatch<TessInput, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            [domain("tri")]
            V2f Domain(TessellationFactors factors, OutputPatch<TessInput, 3> patch,
                       float3 barycentricCoordinates :
                       SV_DomainLocation)
            {
                Appdata v;

                #define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) v.fieldName = \
					patch[0].fieldName * barycentricCoordinates.x + \
					patch[1].fieldName * barycentricCoordinates.y + \
					patch[2].fieldName * barycentricCoordinates.z;

                MY_DOMAIN_PROGRAM_INTERPOLATE(positionOS)
                MY_DOMAIN_PROGRAM_INTERPOLATE(uv)

                return Vert(v);
            }
            ENDHLSL
        }

        //        Pass
        //        {
        //            Name "ShadowCaster"
        //            Tags
        //            {
        //                "LightMode" = "ShadowCaster"
        //            }
        //
        //            ZWrite On
        //            ZTest LEqual
        //            ColorMask 0
        //
        //            HLSLPROGRAM
        //            #pragma exclude_renderers gles gles3 glcore
        //            #pragma target 4.5
        //
        //            // -------------------------------------
        //            // Material Keywords
        //            #pragma shader_feature_local_fragment _ALPHATEST_ON
        //            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        //
        //            //--------------------------------------
        //            // GPU Instancing
        //            #pragma multi_compile_instancing
        //            #pragma multi_compile _ DOTS_INSTANCING_ON
        //
        //            // -------------------------------------
        //            // Universal Pipeline keywords
        //
        //            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
        //            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
        //
        //            #pragma vertex ShadowPassVertex
        //            #pragma fragment ShadowPassFragment
        //
        //            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
        //            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
        //            ENDHLSL
        //        }
    }
}