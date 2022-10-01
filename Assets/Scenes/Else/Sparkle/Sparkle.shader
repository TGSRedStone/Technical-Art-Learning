Shader "Else/Sparkle"
{
    Properties
    {
        _NoiseTex ("NoiseTex", 2d) = "white" {}
        _HeightMap ("HeightMap", 2d) = "white" {}
        _DiffuseColor ("DiffuseColor", color) = (1, 1, 1, 1)
        _ShadowColor ("ShadowColor", color) = (1, 1, 1, 1)
        _RimColor ("RimColor", color) = (1, 1, 1, 1)
        [HDR]_SparkleColor ("SparkleColor", color) = (1, 1, 1, 1)
        _HeightScale ("HeightScale", float) = 1
        _RimPower ("RimPower", float) = 1
        _NoiseOffset ("NoiseOffset", float) = 1
        _FlowSpeed ("FlowSpeed", float) = 1
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
            float4 _NoiseTex_ST;
            float4 _DiffuseColor;
            float4 _ShadowColor;
            float4 _RimColor;
            float4 _SparkleColor;
            float _HeightScale;
            float _RimPower;
            float _NoiseOffset;
            float _FlowSpeed;
            CBUFFER_END

            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_HeightMap); SAMPLER(sampler_HeightMap);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : NORMAL;
                float3 worldPos : TEXCOORD1;
                float3 lightDirTS : TEXCOORD2;
                float3 viewDirTS : TEXCOORD3;
                float3 worldViewDir : TEXCOORD4;
            };
            
            //视差映射
            float2 ParallaxMapping(float heightMulti, float2 uv, float3 viewDirTS)
            {
                float height = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).r;
                float2 offuv = viewDirTS.xy * height * _HeightScale / viewDirTS.z;
                return offuv * heightMulti;
            }

            //https://docs.unity.cn/Packages/com.unity.shadergraph@10.8/manual/Hue-Node.html
            float3 Unity_Hue_Degrees_float(float3 In, float Offset)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
                float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
                float D = Q.x - min(Q.w, Q.y);
                float E = 1e-10;
                float3 hsv = float3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), Q.x);
            
                float hue = hsv.x + Offset / 360;
                hsv.x = (hue < 0)
                        ? hue + 1
                        : (hue > 1)
                            ? hue - 1
                            : hue;
            
                float4 K2 = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 P2 = abs(frac(hsv.xxx + K2.xyz) * 6.0 - K2.www);
                return hsv.z * lerp(K2.xxx, saturate(P2 - K2.xxx), hsv.y);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldViewDir = _WorldSpaceCameraPos.xyz - o.worldPos.xyz;
                o.uv = TRANSFORM_TEX(v.uv, _NoiseTex);
                
                float3 binormal = cross(normalize(v.normal), normalize(v.tangent.xyz)) * v.tangent.w;
                float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
                o.lightDirTS = mul(rotation, TransformWorldToObject(_MainLightPosition.xyz) - v.vertex.xyz);
                o.viewDirTS = mul(rotation, TransformWorldToObject(GetCameraPositionWS()) - v.vertex.xyz);
                
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldLight = normalize(_MainLightPosition.xyz);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                float NdotL = max(0.0, dot(worldNormal, worldLight));
                
                float3 diffuse = lerp(_ShadowColor.rgb, _MainLightColor.rgb * _DiffuseColor.rgb, NdotL);

                float3 sparkle1 = Unity_Hue_Degrees_float(SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv + float2(_Time.x, 0) * _FlowSpeed).rgb, _Time.y * 10) - _NoiseOffset;
                sparkle1 = saturate(dot(sparkle1, 1 - viewDir));
                float3 sparkle2 = Unity_Hue_Degrees_float(SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv + ParallaxMapping(2, i.uv, i.viewDirTS) + float2(0.3 * _Time.x, _Time.x) * _FlowSpeed).rgb, _Time.y * 40) - _NoiseOffset;
                sparkle2 = saturate(dot(sparkle2, 1 - viewDir));
                float3 sparkle3 = Unity_Hue_Degrees_float(SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv + ParallaxMapping(3, i.uv, i.viewDirTS) + float2(_Time.x, 0.6 * _Time.x) * _FlowSpeed).rgb, _Time.y * 90) - _NoiseOffset;
                sparkle3 = saturate(dot(sparkle3, 1 - viewDir));
                float3 sparkle = (sparkle1 + sparkle2 + sparkle3) * _SparkleColor.rgb;
                
                float rim = 1 - saturate(dot(worldNormal, viewDir));
                float3 rimColor = pow(rim, _RimPower) * _RimColor.rgb;
                
                return float4(diffuse + sparkle + rimColor, 1);
            }
            ENDHLSL
        }
    }
}
