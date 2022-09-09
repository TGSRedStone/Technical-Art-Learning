Shader "Template/GerstnerWavesShader"
{
    Properties
    {
        _Gloss ("Gloss", float) = 1
        
        _MainTex ("MainTex", 2d) = "white" {}
        _DiffuseColor("DiffuseColor", color) = (1, 1, 1, 1)
        _SpecularColor("SpecularColor", color) = (1, 1, 1, 1)
        
        _WaveA("WaveA(dir, steepness, wavelength)", vector) = (1, 0, 0.5, 10)
        _WaveB("WaveA(dir, steepness, wavelength)", vector) = (1, 0, 0.5, 10)
        _WaveC("WaveA(dir, steepness, wavelength)", vector) = (1, 0, 0.5, 10)
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
            float _Gloss;
            
            float4 _MainTex_ST;
            float4 _DiffuseColor;
            float4 _SpecularColor;

            float4 _WaveA;
            float4 _WaveB;
            float4 _WaveC;
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

            float3 GerstnerWave(float4 wave, float3 p, inout float3 tangent, inout float3 binormal)
            {
                float steepness = wave.z;
                float2 d = normalize(wave.xy);
                float k = 2 * PI / wave.w;
                float waveSpeed = sqrt(9.8 / k);
                float f = k * (dot(d, p.xz) - waveSpeed * _Time.y);
                float amplitude = steepness / k;

                // float3 tangent = normalize(float3(1 - k * _Amplitude * sin(f), k * _Amplitude * cos(f), 0));
                // v.normal = float3(-tangent.y, tangent.x, 0);

                tangent = float3(1 - d.x * d.x * (steepness * sin(f)),
                d.x * (steepness * cos(f)),  
                -d.y * d.x * (steepness * sin(f)));
                binormal = float3(-d.x * d.y * (steepness * sin(f)),
                d.y * (steepness * cos(f)),
                1 - d.y * d.y * (steepness * sin(f)));

                return float3(d.x * (amplitude * cos(f)), amplitude * sin(f), d.y * (amplitude * cos(f)));
            }

            v2f vert (appdata v)
            {
                v2f o;
                float3 p = v.vertex.xyz;
                float3 tangent = float3(1, 0, 0);
                float3 binormal = float3(0, 0, 1);

                p += GerstnerWave(_WaveA, v.vertex, tangent, binormal);
                p += GerstnerWave(_WaveB, v.vertex, tangent, binormal);
                p += GerstnerWave(_WaveC, v.vertex, tangent, binormal);

                v.normal = normalize(cross(binormal, tangent));
                
                o.vertex = TransformObjectToHClip(p);

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
