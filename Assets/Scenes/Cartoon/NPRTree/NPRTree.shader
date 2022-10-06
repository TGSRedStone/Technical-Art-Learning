Shader "Cartoon/NPRTree"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _ShakeTex ("ShakeTex", 2d) = "white" {}
        [Space(30)]
        _Roughness ("Roughness", float) = 0.3
        _AlbedoLerp ("AlbedoLerp", float) = 0.5
        _SubsurfaceDistortion ("SubsurfaceDistortion", float) = 1
        _AOStrength ("AOStrength", float) = 1
        _SSSStength("SSSStength", float) = 1
        [Header(Rim)]
        _RimWidth ("RimWidth", float) = 1
        _MinRange ("MinRange", float) = 1
        _MaxRange ("MaxRange", float) = 1
        [Space(30)]
        [Header(AlbedoCol1)]
        _Color1 ("Color1", color) = (1, 1, 1, 1)
        [Header(AlbedoCol2)]
        _Color2 ("Color2", color) = (1, 1, 1, 1)
        _RimColor ("RimColor", color) = (1, 1, 1, 1)
        _SSSColor ("SSSColor", color) = (1, 1, 1, 1)
        [Space(30)]
        _SinSpeed ("SinSpeed", vector) = (1, 1, 1, 0)
        _ShakeAmplitude ("ShakeAmplitude", vector) = (1, 1, 1, 0)
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "Queue" = "AlphaTest" "RenderPipeline" = "UniversalPipeline"}
        cull off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float _Roughness;
            float _RimWidth;
            float _MinRange;
            float _MaxRange;
            float4 _Color1;
            float4 _Color2;
            float4 _RimColor;
            float4 _SSSColor;
            float _SubsurfaceDistortion;
            float3 _SinSpeed;
            float3 _ShakeAmplitude;
            float _AlbedoLerp;
            float _AOStrength;
            float _SSSStength;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_ShakeTex); SAMPLER(sampler_ShakeTex);
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 AO : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 worldNormal : NORMAL;
                float4 AO : COLOR;
                float2 uv : TEXCOORD0;
                float3 worldViewDir : TEXCOORD1;
                float4 scrPos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.AO = v.AO;
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldViewDir = GetCameraPositionWS() - worldPos;
                o.scrPos = ComputeScreenPos(o.vertex);
                return o;
            }

            float D_GGX(float a2, float NoH)
            {
                float d = (NoH * a2 - NoH) * NoH + 1; // 2 mad
                return a2 / (PI * d * d);         // 4 mul, 1 rcp
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 shakeTex = SAMPLE_TEXTURE2D(_ShakeTex, sampler_ShakeTex, i.uv);
                
                float3 timeGrow = _Time.y * _SinSpeed;
                float3 shake = sin(timeGrow) * _ShakeAmplitude * shakeTex.rgb;
                float shakeUV = shake.r + shake.y + shake.z;
                
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + shakeUV);
                clip(col.a - 0.5);
                
                float3 worldNormal = normalize(i.worldNormal);
                float3 viewNormal = mul(UNITY_MATRIX_V, float4(worldNormal, 0)).rgb;
                float3 worldViewDir = normalize(i.worldViewDir);
                float3 worldLightDir = normalize(_MainLightPosition.xyz);
                float3 h = normalize(worldLightDir + worldViewDir);
                float NdotL = dot(worldNormal, worldLightDir);
                float NdotH = dot(worldNormal, h);
                
                float2 scrPos = i.scrPos.xy / i.scrPos.w;
                scrPos += viewNormal.xy * _RimWidth * 0.001;
                float depthTex = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, scrPos);
                float depth = LinearEyeDepth(depthTex, _ZBufferParams);
                float rim = saturate(depth - i.scrPos.w);
                rim = smoothstep(min(_MinRange, 0.99), _MaxRange, rim);
                float3 rimColor = rim * _RimColor;
                
                float3 backLightDir = worldNormal * _SubsurfaceDistortion + worldLightDir;
                float backSSS = saturate(dot(worldViewDir, -backLightDir));
                backSSS = saturate(dot(pow(backSSS, 1.6), _SSSStength));

                float3 Albedo = lerp(_Color2, _Color1, NdotL + _AlbedoLerp).rgb;
                float3 ambient = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
                float3 diffuse = lerp(ambient.rgb * Albedo.rgb, _MainLightColor.rgb * Albedo.rgb, NdotL);
                
                float specular = D_GGX(_Roughness * _Roughness, NdotH);
                float3 specularColor = specular * diffuse;

                float3 AO = ambient * i.AO * _AOStrength;
                
                return float4(diffuse + Albedo + specularColor + rimColor + backSSS * _SSSColor.rgb + AO, 1);
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
        
        pass
        {
            Name "DepthOnly"
            Tags {"LightMode" = "DepthOnly"}
            
            ZWrite On
            ColorMask 0
            Cull off
            
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON


            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}
