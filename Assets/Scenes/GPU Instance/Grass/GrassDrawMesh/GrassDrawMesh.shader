Shader "Shaders/GPU Instance/Grass/GrassDrawMesh"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _BreezeNoiseTex ("BreezeNoiseTex", 2d) = "black" {}
        _StrongWindNoiseTex ("StrongWindNoiseTex", 2d) = "black" {}
        _Color1 ("Color1", color) = (1, 1, 1, 1)
        _Color2 ("Color2", color) = (1, 1, 1, 1)
        _ColorGradient ("ColorGradient", range(0, 1)) = 0.5
        _Cutoff("Cutoff", Range(0.0, 1.0)) = 0.5
        _WindDir("WindDir",Vector) = (1,0,0,0)
        _WindStrength ("WindStrength", range(0, 1)) = 0
        _StrongWindStrength ("StrongWindStrength", range(0, 1)) = 0
        _WindNoiseStrength ("WindNoiseStrength", range(0, 1)) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"
        }
        ZWrite On
        ZTest On
        Cull Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Shaders/PBRInclude.hlsl"

            #pragma multi_compile_instancing
            #pragma instancing_options procedural:setup

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            float4x4 _LocalToWorld;
            float4 _Color1;
            float4 _Color2;
            float4 _StrongWindNoiseTex_ST;
            float4 _BreezeNoiseTex_ST;
            float3 _WindDir;
            float2 _GrassQuadSize;
            float _Cutoff;
            float _ColorGradient;
            float _WindStrength;
            float _StrongWindStrength;
            float _WindNoiseStrength;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_BreezeNoiseTex);
            SAMPLER(sampler_BreezeNoiseTex);
            TEXTURE2D(_StrongWindNoiseTex);
            SAMPLER(sampler_StrongWindNoiseTex);

            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                uint instanceID : SV_InstanceID;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
                struct GrassData{
                    float4x4 grassToSpawner;
                    float4 uvOffset;
                };
                StructuredBuffer<GrassData> _GrassDatas;
            #endif

            void setup()
            {
            }

            float3 applyWind(float3 positionWS, float3 grassUpWS, float3 windDir, float windStrength,
                             float vertexHeightOS)
            {
                float rad = windStrength * PI / 2;
                windDir = normalize(windDir - dot(windDir, grassUpWS) * grassUpWS);
                float x, y;
                sincos(rad, x, y);
                float3 windPos = x * windDir + y * grassUpWS;
                return positionWS + (windPos - grassUpWS) * vertexHeightOS;
            }

            v2f vert(appdata v)
            {
                v2f o;
                float2 uv = v.uv;
                float3 normalOS = v.normalOS;
                float3 positionOS = v.positionOS;
                uint instanceID = v.instanceID;
                positionOS.xy *= _GrassQuadSize;

                float3 grassUpDir = float3(0, 1, 0);
                float3 windDir = normalize(_WindDir.xyz);

                #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
                    GrassData grassData = _GrassDatas[instanceID];
                
                    positionOS = mul(grassData.grassToSpawner,float4(positionOS,1)).xyz;
                    normalOS = mul(grassData.grassToSpawner,float4(normalOS,0)).xyz;
                    grassUpDir = mul(grassData.grassToSpawner,float4(grassUpDir,0)).xyz;
                
                    uv = uv * grassData.uvOffset.xy + grassData.uvOffset.zw;
                #endif
                float4 positionWS = mul(_LocalToWorld, float4(positionOS, 1));
                grassUpDir = normalize(mul(_LocalToWorld, float4(grassUpDir, 0)));

                float2 breezeNoiseUV = (positionWS.xz - _Time.y) / 40 * _BreezeNoiseTex_ST.xy + _BreezeNoiseTex_ST.zw;
                float2 strongNoiseUV = float2(positionWS.x, positionWS.z - _Time.y) / 60 * _StrongWindNoiseTex_ST.xy + _StrongWindNoiseTex_ST.zw;
                float breezenoise = SAMPLE_TEXTURE2D_X_LOD(_BreezeNoiseTex, sampler_BreezeNoiseTex, breezeNoiseUV, 0);
                float strongnoise = SAMPLE_TEXTURE2D_X_LOD(_StrongWindNoiseTex, sampler_StrongWindNoiseTex, strongNoiseUV, 0);
                float noise = sin(breezenoise * _WindStrength + strongnoise * _StrongWindStrength);

                float windStrength = noise * _WindNoiseStrength;

                positionWS.xyz = applyWind(positionWS.xyz, grassUpDir, windDir, windStrength, positionOS.y);

                o.uv = uv;
                o.positionWS = positionWS;
                o.normalWS = TransformObjectToWorldNormal(normalOS);
                o.vertex = TransformWorldToHClip(positionWS.xyz);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 diffuse = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                clip(diffuse.a - _Cutoff);
                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 lightDir = mainLight.direction;
                float3 lightColor = mainLight.color;
                float3 worldViewDir = normalize(GetWorldSpaceViewDir(i.positionWS));
                float shadowAttenuation = mainLight.shadowAttenuation;
                float colorGradient = smoothstep(0, _ColorGradient, i.uv.y); //因为没有使用图集这里暂时这样写
                float3 color = lerp(_Color2, _Color1, colorGradient);
                float3 grassColor = max(0.2, abs(dot(lightDir, i.normalWS))) * lightColor * diffuse.rgb * color *
                    shadowAttenuation;
                // grassColor = PBR(i.normalWS, worldViewDir, grassColor, 0, 0.0);
                return float4(grassColor, 1);
            }
            ENDHLSL
        }
    }
}