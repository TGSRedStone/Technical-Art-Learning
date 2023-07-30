Shader "Sand/CartoonSand"
{
    Properties
    {
        _RandomTex ("RandomTex", 2d) = "bump" {}
        _GlitterTex ("GlitterTex", 2d) = "black" {}
        _ShallowTexX ("ShallowTexX", 2d) = "bump" {}
        _ShallowTexZ ("ShallowTexZ", 2d) = "bump" {}
        _SteepTexX ("SteepTexX", 2d) = "bump" {}
        _SteepTexZ ("SteepTexZ", 2d) = "bump" {}
        _TerrainColor ("TerrainColor", color) = (1, 1, 1, 1)
        _ShadowColor ("ShadowColor", color) = (1, 1, 1, 1)
        _RimColor ("RimColor", color) = (1, 1, 1, 1)
        _OceanSpecularColor ("OceanSpecularColor", color) = (1, 1, 1, 1)
        [HDR]_GlitterColor ("GlitterColor", color) = (1, 1, 1, 1)
        _SandStrength ("SandStrength", range(0, 1)) = 0.5
        _RimPower ("RimPower", float) = 25
        _RimStrength ("RimStrength", range(0, 2)) = 0.5
        _SteepnessSharpnessPower ("SteepnessSharpnessPower", float) = 0.5
        _OceanSpecularPower ("OceanSpecularPower", float) = 1
        _OceanSpecularStrength ("OceanSpecularStrength", float) = 1
        _GlitterSpeed ("GlitterSpeed", float) = 1
        _GlitterPower ("GlitterPower", float) = 10
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _RandomTex_ST;
            float4 _GlitterTex_ST;
            float4 _ShallowTexX_ST;
            float4 _ShallowTexZ_ST;
            float4 _SteepTexX_ST;
            float4 _SteepTexZ_ST;
            float4 _TerrainColor;
            float4 _ShadowColor;
            float4 _RimColor;
            float4 _OceanSpecularColor;
            float4 _GlitterColor;
            float _SandStrength;
            float _RimPower;
            float _RimStrength;
            float _SteepnessSharpnessPower;
            float _OceanSpecularPower;
            float _OceanSpecularStrength;
            float _GlitterSpeed;
            float _GlitterPower;
            CBUFFER_END

            TEXTURE2D(_RandomTex);
            SAMPLER(sampler_RandomTex);
            TEXTURE2D(_GlitterTex);
            SAMPLER(sampler_GlitterTex);
            TEXTURE2D(_ShallowTexX);
            TEXTURE2D(_ShallowTexZ);
            SAMPLER(sampler_ShallowTexX);
            SAMPLER(sampler_ShallowTexZ);
            TEXTURE2D(_SteepTexX);
            TEXTURE2D(_SteepTexZ);
            SAMPLER(sampler_SteepTexX);
            SAMPLER(sampler_SteepTexZ);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldTangentDir : TEXCOORD2;
                float3 worldBitangentDir : TEXCOORD3;
                float3 worldNormal : NORMAL;
                float3 worldViewDir : TEXCOORD4;
                half fogCoord: TEXCOORD5;
            };

            float3 DiffuseColor(float3 N, float3 L)
            {
                N.y *= 0.3;
                float NdotL = saturate(4 * dot(N, L));
                float3 color = lerp(_ShadowColor, _TerrainColor, NdotL);
                return color;
            }

            float3 SandNormal(float2 uv, float3 N)
            {
                float3 random = SAMPLE_TEXTURE2D(_RandomTex, sampler_RandomTex, TRANSFORM_TEX(uv, _RandomTex));
                float3 S = normalize(random * 2 - 1);
                float3 Ns = NLerp(N, S, _SandStrength);
                return Ns;
            }

            float3 RimLighting(float3 N, float3 V)
            {
                float rim = 1 - saturate(dot(N, V));
                rim = saturate(pow(rim, _RimPower) * _RimStrength);
                return rim * _RimColor;
            }

            float3 GetRipplesNormal(float2 uv, float3 worldNormal)
            {
                float3 UP_World = float3(0, 1, 0);
                float3 Z_World = float3(0, 0, 1);
                float steepnessX = saturate(dot(worldNormal, UP_World));
                float steepnessZ = saturate(dot(worldNormal, Z_World));
                steepnessX = pow(steepnessX, _SteepnessSharpnessPower);
                steepnessZ = pow(steepnessZ, _SteepnessSharpnessPower);
                float3 shallowX = UnpackNormal(SAMPLE_TEXTURE2D(_ShallowTexX, sampler_ShallowTexX, TRANSFORM_TEX(uv, _ShallowTexX)));
                float3 steepX = UnpackNormal(SAMPLE_TEXTURE2D(_SteepTexX, sampler_SteepTexX, TRANSFORM_TEX(uv, _SteepTexX)));
                float3 shallowZ = UnpackNormal(SAMPLE_TEXTURE2D(_ShallowTexZ, sampler_ShallowTexZ, TRANSFORM_TEX(uv, _ShallowTexZ)));
                float3 steepZ = UnpackNormal(SAMPLE_TEXTURE2D(_SteepTexZ, sampler_SteepTexZ, TRANSFORM_TEX(uv, _SteepTexZ)));
                float3 SX = NLerp(steepX, shallowX, steepnessX);
                float3 SZ = NLerp(steepZ, shallowZ, steepnessZ);
                return SZ;
            }

            float3 OceanSpecular(float3 N, float3 L, float3 V)
            {
                float3 H = normalize(V + L);
                float NdotH = max(0, dot(N, H));
                float specular = pow(NdotH, _OceanSpecularPower) * _OceanSpecularStrength;
                return specular * _OceanSpecularColor;
            }

            float GetGlitterNoise(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_GlitterTex, sampler_GlitterTex, _GlitterTex_ST.xy * uv.xy + _GlitterTex_ST.zw);
            }

            float3 GlitterSpecular(float2 uv, float3 N, float3 L, float3 V)
            {
                // float3 G = normalize(GetGlitterNoise(uv) * 2 - 1);
                // float3 R = reflect(L, G);
                // float RdotV = max(0, dot(R, V));
                // if (RdotV > _GlitterThreshold)
                // {
                //     return 0;
                // }
                // return (1 - RdotV) * _GlitterColor;
                float G1 = GetGlitterNoise(uv + float2 (0.3, _Time.x * 0.001 * _GlitterSpeed));
                float G2 = GetGlitterNoise(uv * 1.4 + float2 (_Time.x * 0.001 * _GlitterSpeed, 0.3));
                float G = pow(G1 * G2 * 1.5, _GlitterPower);
                return G * _GlitterColor;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldTangentDir = normalize(TransformObjectToWorld(v.tangent.xyz));
                o.worldBitangentDir = normalize(cross(o.worldNormal, o.worldTangentDir) * v.tangent.w);
                o.worldViewDir = GetWorldSpaceViewDir(o.worldPos);
                o.fogCoord = ComputeFogFactor(o.vertex.z);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 worldLightDir = normalize(_MainLightPosition.xyz);
                float3 worldViewDir = normalize(i.worldViewDir);
                float3x3 tangentTransform = float3x3(i.worldTangentDir, i.worldBitangentDir, i.worldNormal);
                float3 worldNormal = SandNormal(i.uv, i.worldNormal);
                float3 ripples = GetRipplesNormal(i.uv, worldNormal);
                ripples = mul(ripples, tangentTransform);
                float3 diffuse = DiffuseColor(ripples, worldLightDir);
                float3 rimColor = RimLighting(i.worldNormal, worldViewDir);
                float3 oceanSpecular = OceanSpecular(worldNormal, worldLightDir, worldViewDir);
                float3 specular = saturate(max(rimColor, oceanSpecular));
                float3 glitterColor = GlitterSpecular(i.uv, worldNormal, worldLightDir, worldViewDir);

                float3 color = diffuse + specular + glitterColor;
                color = MixFog(color, i.fogCoord);
                return float4(color, 1);
            }
            ENDHLSL
        }
    }
}