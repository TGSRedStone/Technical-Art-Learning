Shader "Cartoon/FacialShadow"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _IlmTex ("IlmTex", 2d) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
        _ShadowColor ("ShadowColor", color) = (0, 0, 0, 1)
        _LerpMax ("LerpMax", float) = 1
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
            float4 _ShadowColor;
            float _LerpMax;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_IlmTex); SAMPLER(sampler_IlmTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float isSahdow = 0;
                float3 diffuse = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                
                half4 shadowL = SAMPLE_TEXTURE2D(_IlmTex, sampler_IlmTex, i.uv);
                half4 shadowR = SAMPLE_TEXTURE2D(_IlmTex, sampler_IlmTex, float2(1 - i.uv.x, i.uv.y));
                 float3 UP = float3(0,1,0);
                // float2 Left = normalize(TransformObjectToWorldDir(float3(1, 0, 0)).xz);	//世界空间角色正左侧方向向量
                // float2 Front = normalize(TransformObjectToWorldDir(float3(0, 0, 1)).xz);
                float3 Front = float3(0,0,1);
    float3 Left = cross(UP, Front);
                float3 lightDir = normalize(float3(-_MainLightPosition.x, 0, -_MainLightPosition.z));

                float lightAtten = 1 - (dot(lightDir, Front) * 0.5 + 0.5);
                float filpU = sign(dot(lightDir, Left));
                float ilm = filpU > 0 ? shadowL.r : shadowR.r;//确定采样的贴图
                isSahdow = step(ilm, lightAtten);
                float bias = smoothstep(0, _LerpMax, abs(lightAtten - ilm));
                if (lightAtten > 0.99 || isSahdow == 1)
                    diffuse = lerp(diffuse , diffuse * _ShadowColor.xyz ,bias);
                // float3 shaodwRamp = tex2D(_ShaodwRamp, i.uv * float2(filpU, 1));
                
                // float faceShadow = step(lightAtten, shaodwRamp.r);

                
                return float4(diffuse, 1);

            }
            ENDHLSL
        }
    }
}
