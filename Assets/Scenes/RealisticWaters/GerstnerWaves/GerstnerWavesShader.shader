Shader "Waters/GerstnerWaves/GerstnerWavesShader"
{
    Properties
    {
        _NormalScale("NormalScale", range(0, 1)) = 1
        _WaveHeight("WaveHeight", float) = 1
        
        _Color1("Color1", color) = (1, 1, 1, 1)
        _Color2("Color2", color) = (1, 1, 1, 1)
        
        _TopFoamTilingSpeed("TopFoam(Tiling, Speed)", vector) = (1, 1, 1, 1)
        _NormalFlowSpeed("NormalFlowSpeed(Normal1, Normal2)", vector) = (0, 0, 0, 0)      
        
        _TopFoamTex("TopFoamTex", 2d) = "white" {}
        _NormalMap1("NormalMap1", 2d) = "bump" {}
        _NormalMap2("NormalMap2", 2d) = "bump" {}
        
        _WaveA("WaveA(dir, steepness, wavelength)", vector) = (1, 0, 0.5, 10)
        _WaveB("WaveA(dir, steepness, wavelength)", vector) = (1, 0, 0.5, 10)
        _WaveC("WaveA(dir, steepness, wavelength)", vector) = (1, 0, 0.5, 10)
        _WaveD("WaveD(dir, steepness, wavelength)", vector) = (1, 0, 0.5, 10)
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"}

        blend SrcAlpha OneMinusSrcAlpha
        cull off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            float _NormalScale;
            float _WaveHeight;
            
            float4 _TopFoamTilingSpeed;
            float4 _NormalFlowSpeed;
            
            float4 _TopFoamTex_ST;
            float4 _NormalMap1_ST;
            float4 _NormalMap2_ST;
            float4 _Color1;
            float4 _Color2;

            float4 _WaveA;
            float4 _WaveB;
            float4 _WaveC;
            float4 _WaveD;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_TopFoamTex); SAMPLER(sampler_TopFoamTex);
            TEXTURE2D(_NormalMap1); SAMPLER(sampler_NormalMap1);
            TEXTURE2D(_NormalMap2); SAMPLER(sampler_NormalMap2);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 topFoamUV : TEXCOORD1;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 topFoamUV : TEXCOORD1;
                float4 normalUV : TEXCPPRD2;
                float4 vertex : SV_POSITION;
                float4 TtoW0 : TEXCOORD3;
                float4 TtoW1 : TEXCOORD4;
                float4 TtoW2 : TEXCOORD5;
                float3 topFomaMask : TEXCOOED6;
            };

            float3 GerstnerWave(float4 wave, float3 p, inout float3 tangent, inout float3 binormal)
            {
                float steepness = wave.z;
                float2 d = normalize(wave.xy);
                float k = 2 * PI / wave.w;
                float waveSpeed = sqrt(9.8 / k);
                float f = k * (dot(d, p.xz) - waveSpeed * _Time.y);
                float amplitude = steepness / k;

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

                p += GerstnerWave(_WaveA, v.vertex.xyz, tangent, binormal);
                p += GerstnerWave(_WaveB, v.vertex.xyz, tangent, binormal);
                p += GerstnerWave(_WaveC, v.vertex.xyz, tangent, binormal);
                p += GerstnerWave(_WaveD, v.vertex.xyz, tangent, binormal);

                o.topFomaMask = p;

                v.normal = normalize(cross(binormal, tangent));
                
                o.vertex = TransformObjectToHClip(p);

                float3 worldNormal = TransformObjectToWorldNormal(v.normal);
                float3 worldTangent = TransformObjectToWorldDir(tangent);
                float3 worldBinormal = TransformObjectToWorldDir(binormal);
                float3 worldPos = TransformObjectToWorld(p);

                o.normalUV.xy = TRANSFORM_TEX(v.uv, _NormalMap1);
                o.normalUV.zw = TRANSFORM_TEX(v.uv, _NormalMap2);
                o.topFoamUV = worldPos.xz * _TopFoamTilingSpeed.xy * 0.1 - _TopFoamTilingSpeed.zw * _Time.y;

                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                
                return o;
            }

            float3 BlendNormals(float3 n1, float3 n2)
            {
                return normalize(half3(n1.xy + n2.xy, n1.z * n2.z));
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                float3 worldNormal = float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z);
                float3 worldLight = normalize(_MainLightPosition.xyz);
                half3 viewDir = normalize(GetCameraPositionWS() - worldPos);

                //两张法线贴图混合采样+流动控制
                half2 normalUV1 = _Time.y * _NormalFlowSpeed.xy + i.normalUV.xy;
                half2 normalUV2 = _Time.y * _NormalFlowSpeed.zw + i.normalUV.zw;
                float4 topFoamTex = SAMPLE_TEXTURE2D(_TopFoamTex, sampler_TopFoamTex, i.topFoamUV);
                float3 texNormal = BlendNormals(UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap1, sampler_NormalMap1, normalUV1)) , UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap2, sampler_NormalMap2, normalUV2)));
                texNormal = normalize(float3(dot(i.TtoW0.xyz, texNormal), dot(i.TtoW1.xyz, texNormal), dot(i.TtoW2.xyz, texNormal)));
                worldNormal = normalize(worldNormal + texNormal * _NormalScale);
                float NdotL = max(0.0, dot(worldNormal, worldLight));

                //波峰与波谷不同颜色
                float col1Mask = smoothstep(0, _WaveHeight, i.topFomaMask.y);
                float col2Mask = 1 - col1Mask;
                float4 diff = col1Mask * _Color2 + col2Mask * _Color1;

                //兰伯特光照
                float3 diffuse = lerp(UNITY_LIGHTMODEL_AMBIENT.rgb * diff.rgb, _MainLightColor.rgb * diff.rgb, NdotL);

                //顶峰浮沫
                float3 topFomaColor =  smoothstep(1, 2, i.topFomaMask.y) * topFoamTex.rgb / 4;

                //高光部分
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(worldPos));
                half shadow = mainLight.shadowAttenuation;
                BRDFData brdfData;
                half alpha = 1;
                InitializeBRDFData(half3(0, 0, 0), 0, half3(1, 1, 1), 0.9, alpha, brdfData);
                float3 spec = DirectBRDF(brdfData, worldNormal, mainLight.direction, viewDir) * shadow * mainLight.color;

                float3 color = diffuse + spec + topFomaColor;

                return float4(color, 1);
            }
            ENDHLSL
        }
    }
}
