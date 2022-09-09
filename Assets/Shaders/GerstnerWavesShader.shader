Shader "Template/GerstnerWavesShader"
{
    Properties
    {
        _WaveLength("WaveLength", float) = 1
        _WaveSpeed("WaveSpeed", float) = 1
        _Amplitude("Amplitude", float) = 1
        _Gloss ("Gloss", float) = 1
        
        _MainTex ("MainTex", 2d) = "white" {}
        _DiffuseColor("DiffuseColor", color) = (1, 1, 1, 1)
        _SpecularColor("SpecularColor", color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        blend SrcAlpha OneMinusSrcAlpha
        cull off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _WaveLength;
            float _WaveSpeed;
            float _Amplitude;
            float _Gloss;
            
            float4 _MainTex_ST;
            float4 _DiffuseColor;
            float4 _SpecularColor;
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
                float3 worldNormal : NORMAL;
                float3 worldPos : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                float3 p = v.vertex.xyz;
                float k = 2 * PI / _WaveLength;
                float f = k * (p.x - _WaveSpeed * _Time.y);
                p.x += _Amplitude * cos(f);
                p.y += _Amplitude * sin(f);
                o.vertex = TransformObjectToHClip(p);

                float3 tangent = normalize(float3(1 - k * _Amplitude * sin(f), k * _Amplitude * cos(f), 0));
                v.normal = float3(-tangent.y, tangent.x, 0);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);

                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.viewDir = _WorldSpaceCameraPos.xyz - o.worldPos.xyz;

                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldLight = normalize(_MainLightPosition.xyz);
                float3 worldNormal = normalize(i.worldNormal);
                float3 halfDir = normalize(worldLight + i.viewDir);
                
                float NdotH = saturate(dot(halfDir, worldNormal));
                float NdotL = max(0.0, dot(worldNormal, worldLight));

                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                
                float3 diffuse = lerp(col.rgb, _DiffuseColor.rgb,NdotL) + UNITY_LIGHTMODEL_AMBIENT.rgb;
                float3 specular = _MainLightColor.rgb * _SpecularColor.rgb * pow(NdotH, _Gloss);
                
                float3 color = diffuse + specular;

                return float4(color, 1);
            }
            ENDHLSL
        }
    }
}
