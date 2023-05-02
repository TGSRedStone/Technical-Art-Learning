Shader "Shaders/NPRFace"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _ToonTex ("ToonTex", 2d) = "white" {}
        _MatCap ("MatCap", 2d) = "white" {}
        _ShadowRamp ("ShadowRamp", 2d) = "white" {}
        _SDF ("SDF", 2d) = "white" {}
        _FaceShadow ("FaceShadow", 2d) = "white" {}
        _DiffColor ("DiffColor", color) = (1, 1, 1, 1)
        
        _DiffuseColorFac ("DiffuseColorFac", range(0, 1)) = 0.5
        _DiffuseTexFac ("DiffuseTexFac", range(0, 1)) = 0.5
        _ToonTexFac ("ToonTexFac", range(0, 1)) = 0.5
        _MatcapTexFac ("MatcapTexFac", range(0, 1)) = 0.5
        _MatcapMullAdd ("MatcapMullAdd", range(0, 1)) = 1
        _Alpha ("Alpha", range(0, 1)) = 1
        
        _RampTexRow0 ("RampTexRow0", int) = 1
        
        _ShadowColor ("ShadowColor", color) = (1, 1, 1, 1)
        
        _ForwardVector ("ForwardVector", vector) = (0, 0, 1, 0)
        _RightVector ("RightVector", vector) = (1, 0, 0, 0)
        
//        _HairShadowDistace ("HairShadowDistace", float) = 1
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            // #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            // #pragma multi_compile _ _SHADOWS_SOFT
            
            
            #pragma vertex vert
            #pragma fragment frag

            // #pragma multi_compile_local _ _IsFace

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_MatCap); SAMPLER(sampler_MatCap);
            TEXTURE2D(_ToonTex); SAMPLER(sampler_ToonTex);
            TEXTURE2D(_ShadowRamp); SAMPLER(sampler_ShadowRamp);
            TEXTURE2D(_SDF); SAMPLER(sampler_SDF);
            TEXTURE2D(_FaceShadow); SAMPLER(sampler_FaceShadow);
            // TEXTURE2D(_HairSoildColor); SAMPLER(sampler_HairSoildColor);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _DiffColor;
                float4 _ShadowColor;
                float4 _ForwardVector;
                float4 _RightVector;
                float _DiffuseColorFac;
                float _DiffuseTexFac;
                float _ToonTexFac;
                float _MatcapTexFac;
                float _MatcapMullAdd;
                float _Alpha;
                // float _HairShadowDistace;

                float _RampTexRow0;
            CBUFFER_END

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 clipPos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 NDCpos : TEXCOORD3;
                float3 worldNormal : TEXCOORD4;
                float4 shadowCoord : TEXCOORD7;
                // #if _IsFace
                //     float4 screenPos: TEXCOORD8;
                // #endif
            };

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs vpi = GetVertexPositionInputs(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.clipPos = vpi.positionCS;
                o.worldPos = vpi.positionWS;
                o.NDCpos = vpi.positionNDC;

                VertexNormalInputs vni = GetVertexNormalInputs(v.normal, v.tangent);
                o.worldNormal = vni.normalWS;

                o.shadowCoord = TransformWorldToShadowCoord(vpi.positionWS);

                // #if _IsFace
                //     o.screenPos = ComputeScreenPos(vpi.positionCS);
                // #endif
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                Light light = GetMainLight(i.shadowCoord);
                
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldView = normalize(GetWorldSpaceViewDir(i.worldPos));
                float3 worldLight = normalize(light.direction);
                float3 viewNormal = normalize(mul((float3x3)UNITY_MATRIX_V, worldNormal));

                float NDotV = saturate(dot(worldNormal, worldView)) + 1e-5f;

                float2 matcapUV = worldNormal.xy * 0.5 + 0.5;
                float4 diffuseTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float4 toonTex = SAMPLE_TEXTURE2D(_ToonTex, sampler_ToonTex, matcapUV);
                float4 matcap = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, matcapUV);

                float3 ambientCol = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
                float3 baseCol = ambientCol;
                baseCol = saturate(lerp(baseCol, ambientCol + _DiffColor.rgb, _DiffuseColorFac));
                baseCol = lerp(baseCol, baseCol * diffuseTex.rgb, _DiffuseTexFac);
                baseCol = lerp(baseCol, baseCol * toonTex.rgb, _ToonTexFac);
                baseCol = lerp(lerp(baseCol, baseCol * matcap.rgb, _MatcapTexFac), lerp(baseCol, baseCol + matcap.rgb, _MatcapTexFac), _MatcapMullAdd);

                float rampV = _RampTexRow0 / 10.0 - 0.05;
                float2 rampDayUV = float2(0.003, 1 - rampV);
                float2 rampNightUV = float2(0.003, 1 - (rampV + 0.5));

                float isDay = (light.direction.y + 1) / 2;
                float3 rampColor = lerp(SAMPLE_TEXTURE2D(_ShadowRamp, sampler_ShadowRamp, rampNightUV).rgb, SAMPLE_TEXTURE2D(_ShadowRamp, sampler_ShadowRamp, rampDayUV).rgb, isDay);
                
                float3 forwardVector = _ForwardVector;
                float3 rightVector = _RightVector;
                float3 upVector = cross(forwardVector, rightVector);
                float3 LightProjectionUp = dot(worldLight, upVector) / pow(length(upVector), 2) * upVector;
                float3 LpHeadHorizon = worldLight - LightProjectionUp;
                
                float pi = 3.14159265358979323846;
                float value = acos(dot(normalize(LpHeadHorizon), normalize(rightVector))) / pi;
                float exposeRight = step(value, 0.5);
                
                float valueR = pow(1 - value * 2, 3);
                float valueL = pow(value * 2 - 1, 3);
                float mixValue = lerp(valueL, valueR, exposeRight);
                
                float sdfLeft = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, float2(1 - i.uv.x, i.uv.y)).r;
                float sdfRight = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, i.uv).r;
                float mixSdf = lerp(sdfRight, sdfLeft, exposeRight);
                float sdf = step(mixValue, mixSdf);
                sdf = lerp(0, sdf, step(0, dot(normalize(LpHeadHorizon), normalize(forwardVector))));

                float4 shadowTex = SAMPLE_TEXTURE2D(_FaceShadow, sampler_FaceShadow, i.uv);
                sdf *= shadowTex.r;
                sdf = lerp(sdf, 1, shadowTex.a);

                float3 shadowColor = baseCol * rampColor * _ShadowColor;
                
                float3 diffuse = lerp(shadowColor, baseCol, sdf);
                diffuse = lerp(shadowColor, diffuse, light.shadowAttenuation);

                float3 albedo = diffuse;

                float rimOffset = 6;
                float rimThreshold = 0.03;
                float rimStrength = 0.6;
                float rimMax = 0.3;

                float2 screenUV = i.NDCpos.xy / i.NDCpos.w;
                float rawDepth = SampleSceneDepth(screenUV);
                float linearDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                float2 screenOffset = float2(lerp(-1, 1, step(0, viewNormal.x)) * rimOffset / _ScreenParams.x / max(1, pow(linearDepth, 2)), 0);
                float offsetDepth = SampleSceneDepth(screenUV + screenOffset);
                float offsetlinearDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);

                float rim = saturate(offsetlinearDepth - linearDepth);
                rim = step(rimThreshold, rim) * clamp(rim * rimStrength, 0, rimMax);

                float fresnelPower = 6;
                float fresnelClamp = 0.8;
                float fresnel = 1 - saturate(NDotV);
                fresnel = pow(fresnel, fresnelPower);
                fresnel = fresnel * fresnelClamp + (1 - fresnelClamp);

                albedo = 1 - (1 - rim * fresnel) * (1 - albedo);

                // #if _IsFace
                //     float heightCorrect = smoothstep(_HeightCorrectMax, _HeightCorrectMin, i.worldPos.y);
                //
                //     float depth = (i.clipPos.z / i.clipPos.w);
                //     
                //     float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);
                //     //计算该像素的Screen Position
                //     float2 scrPos = i.screenPos.xy / i.screenPos.w;
                //
                //     //计算View Space的光照方向
                //     float3 viewLightDir = normalize(TransformWorldToViewDir(light.direction)) * (1 / min(i.NDCpos.w, 1)) * min(1, 5 / linearEyeDepth);
                //
                //     //计算采样点，其中_HairShadowDistace用于控制采样距离
                //     float2 samplingPoint = scrPos + _HairShadowDistace * viewLightDir.xy;
                //
                //
                //     //若采样点在阴影区内,则取得的value为1,作为阴影的话还得用1 - value;
                //     float hairDepth = SAMPLE_TEXTURE2D(_HairSoildColor, sampler_HairSoildColor, samplingPoint).g;
                //     hairDepth = LinearEyeDepth(hairDepth, _ZBufferParams);
                //     
                //     float depthContrast = linearEyeDepth  > hairDepth * heightCorrect - 0.01 ? 0: 1;
                //     //将作为二分色依据的ramp乘以shadow值
                //     albedo *= depthContrast;
                // #endif
                
                float alpha = _Alpha * diffuseTex.a * toonTex.a * matcap.a;

                float4 col = float4(albedo, alpha);

                return col;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}
