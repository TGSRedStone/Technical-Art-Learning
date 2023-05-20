Shader "Fur/BaseFur"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
        _FurMask ("FurMask", 2d) = "white" {}
        
        _Color ("Color", color) = (1, 1, 1, 1)
        _Specular ("Specular", color) = (0, 0, 0, 1)
        _Shininess ("Shininess", range(0.01, 128.0)) = 8.0
        
        _FurLength ("Fur Length", range(0.0, 1)) = 0.5
        _FurDensity ("FurDensity", float) = 1
        _FurThinness ("FurThinness", float) = 1
        _FurShading ("FurShading", float) = 1
        
        _RimeColor ("RimeColor", color) = (1, 1, 1, 1)
        _RimPower ("RimPower", float) = 1
        
        _ForceGlobal ("ForceGlobal", vector) = (0.1, 0.1, 0.1, 0.1)
        _ForceLocal ("ForceLocal", vector) = (0.1, 0.1, 0.1, 0.1)
    }
    SubShader
    {
        Cull off
        Zwrite On
        Blend SrcAlpha OneMinusSrcAlpha
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "Queue"="Transparent"}
        
        pass
        {
            cull back
            
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float4 _Specular;
            half _Shininess;

            float4 _MainTex_ST;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldLight = normalize(_MainLightPosition.xyz);
                float3 worldView = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                float3 worldHalf = normalize(worldView + worldLight);
            
                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy).rgb * _Color.rgb;
                float3 ambient = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) * albedo;
                float3 diffuse = _MainLightColor.rgb * albedo * saturate(dot(worldNormal, worldLight));
                float3 specular = _MainLightColor.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, worldHalf)), _Shininess);
            
                float3 color = ambient + diffuse + specular;
            
                return float4(color, 1.0);
            }
            
            ENDHLSL
        }

        pass
        {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float4 _Specular;
            half _Shininess;

            float _FurStep;
            float _FurLength;
            float _FurDensity;
            float _FurThinness;
            float _FurShading;
            
            float4 _ForceGlobal;
            float4 _ForceLocal;
            
            float4 _RimColor;
            half _RimPower;

            float4 _MainTex_ST;
            float4 _FurMask_ST;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_FurMask); SAMPLER(sampler_FurMask);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                float3 p = v.vertex.xyz + v.normal * _FurLength * _FurStep;
                p += clamp(mul(unity_WorldToObject, _ForceGlobal).xyz + _ForceLocal.xyz, -1, 1) * pow(_FurStep, 3) * _FurLength;
                o.vertex = TransformObjectToHClip(p);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.uv, _FurMask);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldLight = normalize(_MainLightPosition.xyz);
                float3 worldView = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                float3 worldHalf = normalize(worldView + worldLight);
            
                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy).rgb * _Color.rgb;
                albedo -= pow(1 - _FurStep, 3) * _FurShading;
                half rim = 1.0 - saturate(dot(worldView, worldNormal));
                albedo += _RimColor.rgb * pow(rim, _RimPower);
                
                float3 ambient = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) * albedo;
                float3 diffuse = _MainLightColor.rgb * albedo * saturate(dot(worldNormal, worldLight));
                float3 specular = _MainLightColor.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, worldHalf)), _Shininess);
            
                float3 color = ambient + diffuse + specular + _RimColor.rgb * pow(rim, _RimPower);
                float mask = SAMPLE_TEXTURE2D(_FurMask, sampler_FurMask, i.uv.zw * _FurThinness).r;
                float alpha = clamp(mask - (_FurStep * _FurStep) * _FurDensity, 0, 1);

                return float4(color, alpha);
            }
            ENDHLSL
        }
    }
}
