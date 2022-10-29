Shader "Cartoon/Sand"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _RandomNoiseTex ("RandomNoiseTex", 2d) = "black" {}
        _TerrainColor ("TerrainColor", color) = (1, 1, 1, 1)
        _ShadowColor ("ShadowColor", color) = (1, 1, 1, 1)
        [HDR]_RimColor ("RimColor", color) = (1, 1, 1, 1)
        [HDR]_OceanSpecularColor ("OceanSpecularColor", color) = (1, 1, 1, 1)
        _NormalLerp ("NormalLerp", range(0, 1)) = 0.5
        _RimPower ("RimPower", float) = 1
        _RimStrength ("RimStrength", float) = 1
        _OceanSpecularPower ("OceanSpecularPower", float) = 1
        _OceanSpecularStrength ("OceanSpecularStrength", float) = 1
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
            float4 _RandomNoiseTex_ST;
            float4 _TerrainColor;
            float4 _ShadowColor;
            float4 _RimColor;
            float4 _OceanSpecularColor;
            float _NormalLerp;
            float _RimPower;
            float _RimStrength;
            float _OceanSpecularPower;
            float _OceanSpecularStrength;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_RandomNoiseTex); SAMPLER(sampler_RandomNoiseTex);

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
                float3 worldViewDir : TEXCOORD1;
                float3 worldLightDir : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldViewDir = GetCameraPositionWS() - worldPos;
                o.worldLightDir = _MainLightPosition.xyz;
                o.uv = v.uv;
                return o;
            }

            float3 nlerp(float3 n1, float3 n2, float t)
            {
                return normalize(lerp(n1, n2, t));
            }

            float3 Diffuse(float3 N, float3 L)
            {
                N.y *= 0.3;
                float NdotL = saturate(4 * dot(N, L));
                float3 color = lerp(_ShadowColor.rgb, _TerrainColor.rgb, NdotL);
                return color;
            }

            float3 Rim(float3 N, float3 V)
            {
                float rim = 1.0 - saturate(dot(N, V));
                rim = saturate(pow(rim, _RimPower) * _RimStrength);
                rim = max(rim, 0);
                return rim * _RimColor;
            }

            float3 OceanSpecular(float3 N, float3 L, float3 V)
            {
                float3 H = normalize(V + L); // Half direction
                float NdotH = max(0, dot(N, H));
                float specular = pow(NdotH, _OceanSpecularPower) * _OceanSpecularStrength;
                return specular * _OceanSpecularColor;
            }

            float3 SandNormal(float2 uv, float3 N)
            {
                float3 random = SAMPLE_TEXTURE2D(_RandomNoiseTex, sampler_RandomNoiseTex, TRANSFORM_TEX(uv, _RandomNoiseTex)).rgb;
                float3 S = normalize(random * 2 - 1);
                S = nlerp(N, S, _NormalLerp);
                return S;
            }

            float4 frag (v2f i) : SV_Target
            {
                //N = RipplesNormal(N);
                float3 N = normalize(i.worldNormal);
                float3 V = normalize(i.worldViewDir);
                float3 L = normalize(i.worldLightDir);

                float3 rim = Rim(N, V);

                N = SandNormal(i.uv, N);
                // return float4(N, 1);

                float3 diffuse = Diffuse(N, L);

                
                float3 oceanSpecular = OceanSpecular(N, L, V);

                float3 specular = saturate(max(rim, oceanSpecular));
                float3 color = diffuse + specular;
                
                return float4(color, 1);

            }
            ENDHLSL
        }
    }
}
