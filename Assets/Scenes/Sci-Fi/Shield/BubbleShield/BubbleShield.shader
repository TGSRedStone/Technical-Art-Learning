Shader "Sci-Fi/Shield/BubbleShield"
{
    Properties
    {
        _HoneyCombTex ("HoneyCombTex", 2d) = "white" {}
        _RimStrength ("_RimStength", range(0, 1.5)) = 0.5
        _GlowPower ("GlowPower", float) = 1
        [HDR]_EdgeColor ("EdgeColor", color) = (1, 1, 1, 1)
        [HDR]_HitColor ("HitColor", color) = (1, 1, 1, 1)
        _TotalColor ("TotalColor", color) = (1, 1, 1, 1)
        [HDR]_HoneyCombColor ("HoneyCombColor", color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline"}

        blend one one

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _HoneyCombTex_ST;
            float4 _EdgeColor;
            float4 _TotalColor;
            float4 _HoneyCombColor;
            float4 _HitColor;
            float _RimStrength;
            float _GlowPower;
            float _Points[4];
            CBUFFER_END

            TEXTURE2D(_HoneyCombTex); SAMPLER(sampler_HoneyCombTex);
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 scrPos : TEXCOORD1;
                float4 objPos : TEXCOORD2;
                float depth : DEPTH;
                float3 worldPos : TEXCOORD3;
                float3 worldNormal : TEXCOORD4;
                float3 worldViewDir : TEXCOORD5;
            };

            //https://www.cyanilux.com/tutorials/forcefield-shader-breakdown/
            float Test_float(float3 worldPos)
            {
                float3 p = float3(_Points[0], _Points[1], _Points[2]); // Position
                float t = _Points[3]; // Lifetime
                
                // Ripple Shape :
                float rippleSize = 1;
                float gradient = smoothstep(t / 3, t, distance(worldPos, p) / rippleSize);
                 
                // frac means it will have a sharp edge, while sine makes it more "soft"
                float ripple = saturate(sin(5 * gradient));
                 
                float lifetimeFade = saturate(1 - t); // Goes from 1 at t=0, to 0 at t=1
                float rippleStrength = lifetimeFade * ripple;
                 
                return rippleStrength;
            }

            v2f vert (appdata v)
            {
                v2f o;
                
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.scrPos = ComputeScreenPos(o.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv.xy, _HoneyCombTex);
                o.objPos = v.vertex;
                o.depth = -TransformWorldToView(TransformObjectToWorld(v.vertex.xyz)).z * _ProjectionParams.w;
                o.worldNormal = normalize(TransformObjectToWorldNormal(v.normal));
                o.worldViewDir = normalize(GetCameraPositionWS() - o.worldPos);
                return o;
            }

            float Wave(float t, float offset, float yOffset)
            {
                return saturate(abs(frac(offset + t) * 2 - 1) + yOffset);
            }

            float4 frag (v2f i) : SV_Target
            {
                float NdotH = dot(i.worldNormal, i.worldViewDir);
                float2 screenPos = i.scrPos.xy / i.scrPos.w;
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenPos).r;

                half linearDepth = Linear01Depth(depth, _ZBufferParams);
                half diff = linearDepth - i.depth;
                half intersect = 1 - smoothstep(0, _ProjectionParams.w * _RimStrength, diff);
                half rim = 1 - saturate(abs(NdotH) / _RimStrength);
                half glow = max(intersect, rim);
                float4 glowColor = float4(lerp(_TotalColor.rgb, _EdgeColor.rgb, pow(glow, _GlowPower)), 1);

                float4 honeyCombTex = SAMPLE_TEXTURE2D(_HoneyCombTex, sampler_HoneyCombTex, i.uv);
                honeyCombTex.g *= Wave(_Time.x * 5, abs(i.objPos.y) * 2, -0.6) * 2;
                honeyCombTex.g *= (sin(_Time.z + honeyCombTex.b * 5) + 1) / 2;
                
                float strength = Test_float(i.worldPos);
                return glowColor + strength * honeyCombTex.r * _HitColor + honeyCombTex.g * _HoneyCombColor;
            }
            ENDHLSL
        }
    }
}
