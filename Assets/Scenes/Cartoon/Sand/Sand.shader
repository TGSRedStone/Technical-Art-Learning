Shader "Cartoon/Sand"
{
    Properties
    {
        _RandomNoiseTex ("RandomNoiseTex", 2d) = "black" {}
        _GlitterTex ("GlitterTex", 2d) = "black" {}
        _ShallowTex ("ShallowTex", 2d) = "black" {}
        _SteepTex ("SteepTex", 2d) = "black" {}
        _TerrainColor ("TerrainColor", color) = (1, 1, 1, 1)
        _ShadowColor ("ShadowColor", color) = (1, 1, 1, 1)
        [HDR]_RimColor ("RimColor", color) = (1, 1, 1, 1)
        [HDR]_OceanSpecularColor ("OceanSpecularColor", color) = (1, 1, 1, 1)
        [HDR]_GlitterColor ("GlitterColor", color) = (1, 1, 1, 1)
        _NormalLerp ("NormalLerp", range(0, 1)) = 0.5
        _RimPower ("RimPower", float) = 1
        _RimStrength ("RimStrength", float) = 1
        _OceanSpecularPower ("OceanSpecularPower", float) = 1
        _OceanSpecularStrength ("OceanSpecularStrength", float) = 1
        _GlitterThreshold ("GlitterThreshold", range(0, 1)) = 1
        _SteepnessSharpnessPower ("SteepnessSharpnessPower", float) = 1
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
            float4 _RandomNoiseTex_ST;
            float4 _GlitterTex_ST;
            float4 _ShallowTex_ST;
            float4 _SteepTex_ST;
            float4 _TerrainColor;
            float4 _ShadowColor;
            float4 _RimColor;
            float4 _OceanSpecularColor;
            float4 _GlitterColor;
            float _NormalLerp;
            float _RimPower;
            float _RimStrength;
            float _OceanSpecularPower;
            float _OceanSpecularStrength;
            float _GlitterThreshold;
            float _SteepnessSharpnessPower;
            CBUFFER_END

            TEXTURE2D(_GlitterTex); SAMPLER(sampler_GlitterTex);
            TEXTURE2D(_ShallowTex); SAMPLER(sampler_ShallowTex);
            TEXTURE2D(_SteepTex); SAMPLER(sampler_SteepTex);
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

            float3 GlitterSpecular(float2 uv, float3 L, float3 V)
            {
                float3 G = normalize(SAMPLE_TEXTURE2D(_GlitterTex, sampler_GlitterTex, TRANSFORM_TEX(uv, _GlitterTex)).rgb * 2 - 1);

                float3 R = reflect(L, G);
                float RdotV = max(0, dot(R, V) - _GlitterThreshold);
                
                return RdotV * _GlitterColor;
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
                float3 worldNormal = normalize(i.worldNormal);
                float3 V = normalize(i.worldViewDir);
                float3 L = normalize(i.worldLightDir);

                float3 UP_WORLD = float3(0, 1, 0);
                float steepness = atan( 1/ worldNormal.y ) ;
				steepness = saturate( pow( steepness , 3 ) );

                float xzRate = atan(abs( worldNormal.z / worldNormal.x));
                xzRate = saturate( pow( xzRate , 9 ) );
                float3 shallow = UnpackNormal(SAMPLE_TEXTURE2D(_ShallowTex, sampler_ShallowTex, TRANSFORM_TEX(i.uv, _ShallowTex)));
                float3 steepX   = UnpackNormal(SAMPLE_TEXTURE2D(_SteepTex, sampler_SteepTex, TRANSFORM_TEX(i.uv, _SteepTex)));
                float3 steepZ   = UnpackNormal(SAMPLE_TEXTURE2D(_SteepTex, sampler_SteepTex, TRANSFORM_TEX(i.uv, _SteepTex)));
                float3 steep = nlerp(steepX, steepZ, xzRate);

                float3 Normal = normalize(lerp(shallow, steep, steepness));

                float3 N = SandNormal(i.uv, Normal * 0.3 + worldNormal);
                
                float3 diffuse = Diffuse(N, L);

                float3 rim = Rim(worldNormal, V);
                
                float3 oceanSpecular = OceanSpecular(N, L, V);

                float3 specular = saturate(max(rim, oceanSpecular));
                float3 glitterColor = GlitterSpecular(i.uv, L, V);
                float3 color = diffuse + specular + glitterColor;

                return float4(color, 1);

            }
            ENDHLSL
        }
    }
}
