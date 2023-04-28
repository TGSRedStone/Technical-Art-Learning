Shader "Shaders/ShowVertexColor"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _NormalTex ("NormalTex", 2d) = "bump" {}
        _ToonTex ("ToonTex", 2d) = "white" {}
        _MatCap ("MatCap", 2d) = "white" {}
        _ShadowRamp ("ShadowRamp", 2d) = "white" {}
        _LightMap ("LightMap", 2d) = "white" {}
        _DiffColor ("DiffColor", color) = (1, 1, 1, 1)
        
        _DiffuseColorFac ("DiffuseColorFac", range(0, 1)) = 0.5
        _DiffuseTexFac ("DiffuseTexFac", range(0, 1)) = 0.5
        _ToonTexFac ("ToonTexFac", range(0, 1)) = 0.5
        _MatcapTexFac ("MatcapTexFac", range(0, 1)) = 0.5
        _MatcapMullAdd ("MatcapMullAdd", range(0, 1)) = 1
        _BlinnPhongPower ("BlinnPhongPower", range(1, 128)) = 25
        
        _RampTexRow0 ("RampTexRow0", int) = 1
        _RampTexRow1 ("RampTexRow1", int) = 4
        _RampTexRow2 ("RampTexRow2", int) = 3
        _RampTexRow3 ("RampTexRow3", int) = 5
        _RampTexRow4 ("RampTexRow4", int) = 2
        
        _ShadowColor ("ShadowColor", color) = (1, 1, 1, 1)
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

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalTex); SAMPLER(sampler_NormalTex);
            TEXTURE2D(_MatCap); SAMPLER(sampler_MatCap);
            TEXTURE2D(_ToonTex); SAMPLER(sampler_ToonTex);
            TEXTURE2D(_ShadowRamp); SAMPLER(sampler_ShadowRamp);
            TEXTURE2D(_LightMap); SAMPLER(sampler_LightMap);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _DiffColor;
                float4 _ShadowColor;
                float _DiffuseColorFac;
                float _DiffuseTexFac;
                float _ToonTexFac;
                float _MatcapTexFac;
                float _MatcapMullAdd;
                float _BlinnPhongPower;

                float _RampTexRow0;
                float _RampTexRow1;
                float _RampTexRow2;
                float _RampTexRow3;
                float _RampTexRow4;
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
                float3 viewPos : TEXCOORD2;
                float4 NDCpos : TEXCOORD3;
                float3 worldNormal : TEXCOORD4;
                float3 worldTangent : TEXCOORD5;
                float3 worldBitangent : TEXCOORD6;
            };

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs vpi = GetVertexPositionInputs(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.clipPos = vpi.positionCS;
                o.worldPos = vpi.positionWS;
                o.viewPos = vpi.positionVS;
                o.NDCpos = vpi.positionNDC;

                VertexNormalInputs vni = GetVertexNormalInputs(v.normal, v.tangent);
                o.worldNormal = vni.normalWS;
                o.worldTangent = vni.tangentWS;
                o.worldBitangent = vni.bitangentWS;
                
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv);
                float3 tangentNormal = UnpackNormal(normalMap.agbr);

                float3 worldNormal = normalize(mul(tangentNormal, float3x3(i.worldTangent, i.worldBitangent, i.worldNormal)));
                float3 worldView = normalize(GetWorldSpaceViewDir(i.worldPos));
                float3 worldLight = normalize(_MainLightPosition.xyz);
                float3 halfVector = normalize(worldLight + worldView);

                float NDotL = saturate(dot(worldNormal, worldLight)) + 1e-5f;
                float NDotV = saturate(dot(worldNormal, worldView)) + 1e-5f;
                float NDotH = saturate(dot(worldNormal, halfVector)) + 1e-5f;

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

                float4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, i.uv);

                float shadowRampEnum0 = 0.0;
                float shadowRampEnum1 = 0.3;
                float shadowRampEnum2 = 0.5;
                float shadowRampEnum3 = 0.7;
                float shadowRampEnum4 = 1.0;

                float ramp0 = _RampTexRow0 / 10.0 - 0.05; //0.05
                float ramp1 = _RampTexRow1 / 10.0 - 0.05; //0.35
                float ramp2 = _RampTexRow2 / 10.0 - 0.05; //0.25
                float ramp3 = _RampTexRow3 / 10.0 - 0.05; //0.45
                float ramp4 = _RampTexRow4 / 10.0 - 0.05; //0.15

                float shadowRampDayV = lerp(ramp4, ramp3, step(lightMap.a, (shadowRampEnum4 + shadowRampEnum3) / 2));
                shadowRampDayV = lerp(shadowRampDayV, ramp2, step(lightMap.a, (shadowRampEnum3 + shadowRampEnum2) / 2));
                shadowRampDayV = lerp(shadowRampDayV, ramp1, step(lightMap.a, (shadowRampEnum2 + shadowRampEnum1) / 2));
                shadowRampDayV = lerp(shadowRampDayV, ramp0, step(lightMap.a, (shadowRampEnum1 + shadowRampEnum0) / 2));
                float nightRampV = shadowRampDayV + 0.5;

                float halfLambert = pow(NDotL * 0.5 + 0.5, 2);
                float halfLambertStep = smoothstep(0.423, 0.450, halfLambert);

                float shadowRampU = clamp(smoothstep(0.2, 0.4, halfLambert), 0.003, 0.997);
                float2 grayShadowRampDayUV = float2(shadowRampU, 1 - shadowRampDayV);
                float2 grayShadowRampNightUV = float2(shadowRampU, 1 - nightRampV);

                float2 darkShadowRampDayUV = float2(0.003, 1 - shadowRampDayV);
                float2 darkShadowRampNightUV = float2(0.003, 1 - nightRampV);

                float isDay = (_MainLightPosition.y + 1) / 2;

                float3 grayShadowRampCol = lerp(SAMPLE_TEXTURE2D(_ShadowRamp, sampler_ShadowRamp, grayShadowRampNightUV).rgb, SAMPLE_TEXTURE2D(_ShadowRamp, sampler_ShadowRamp, grayShadowRampDayUV).rgb, isDay);
                float3 darkShadowRampCol = lerp(SAMPLE_TEXTURE2D(_ShadowRamp, sampler_ShadowRamp, darkShadowRampNightUV).rgb, SAMPLE_TEXTURE2D(_ShadowRamp, sampler_ShadowRamp, darkShadowRampDayUV).rgb, isDay);

                float3 garyShadowCol = baseCol * grayShadowRampCol * _ShadowColor;
                float3 darkShadowCol = baseCol * darkShadowRampCol * _ShadowColor;

                float3 diffuse = 0;
                diffuse = lerp(garyShadowCol, baseCol, halfLambertStep);
                diffuse = lerp(darkShadowCol, diffuse, saturate(lightMap.g * 2));
                diffuse = lerp(diffuse, baseCol, saturate(lightMap.g - 0.5) * 2);

                float blinnPhong = pow(NDotH, _BlinnPhongPower);
                float3 nonMetallicSpec = step(1.04 - blinnPhong, lightMap.b) * lightMap.r;
                float3 metallicSpec = blinnPhong * lightMap.b * (halfLambertStep * 0.8 + 0.2) * baseCol;

                float isMetal = step(0.95, lightMap.r);
                float3 specular = lerp(nonMetallicSpec, metallicSpec, isMetal);

                return float4(specular, 1);
            }
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
