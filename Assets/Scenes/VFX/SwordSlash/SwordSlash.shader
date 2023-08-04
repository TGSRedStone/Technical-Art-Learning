Shader "VFX/SwordSlash"
{
    Properties
    {
        [NoScaleOffset]_MainTex ("MainTex", 2d) = "white" {}
        _MainTexUFlowSpeed ("MainTexUFlowSpeed", float) = 0
        _MainTexVFlowSpeed ("MainTexVFlowSpeed", float) = 0
        [NoScaleOffset]_DissolveTex ("DissolveTex", 2d) = "white" {}
        _DissolveUV ("DissolveUV", vector) = (1, 1, 0, 0)
        [NoScaleOffset]_SerrationTex ("SerrationTex", 2d) = "white" {}
        _SerrationUV ("SerrationUV", vector) = (1, 1, 0, 0)
        _SerrationRotate ("SerrationRotate", range(0, 360)) = 0
        [NoScaleOffset]_DistortTex ("DistortTex", 2d) = "black" {}
        _DistortUV ("DistortUV", vector) = (1, 1, 0, 0)
        _DissolveStrength ("DissolveStrength", range(0, 1)) = 0
        _DissolveSoft ("DissolveSoft", range(0, 1)) = 0
        _ColorStrength ("ColorStrength", float) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            zwrite off
            cull off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _DissolveUV;
            float4 _SerrationUV;
            float4 _DistortUV;
            float _ColorStrength;
            float _DissolveStrength;
            float _DissolveSoft;
            float _SerrationRotate;
            float _MainTexUFlowSpeed;
            float _MainTexVFlowSpeed;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_DissolveTex);
            SAMPLER(sampler_DissolveTex);
            TEXTURE2D(_SerrationTex); SAMPLER(sampler_SerrationTex);
            TEXTURE2D(_DistortTex); SAMPLER(sampler_DistortTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float4 uv : TEXCOORD0;
                float4 customData : TEXCOORD1;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float4 uv : TEXCOORD0;
                float4 customData : TEXCOORD1;
            };

            float2 Rotate_Degrees(float2 uv, float rotation)
            {
                rotation = rotation * (3.1415926f / 180.0f);
                float2 center = float2(0.5, 0.5);
                uv -= center;
                float s = sin(rotation);
                float c = cos(rotation);
                float2x2 rMatrix = float2x2(c, -s, s, c);
                rMatrix *= 0.5;
                rMatrix += 0.5;
                rMatrix = rMatrix * 2 - 1;
                uv.xy = mul(uv.xy, rMatrix);
                uv += center;
                return uv;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.color = v.color;
                o.customData = v.customData;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 distUV = i.uv * _DistortUV.xy + _DistortUV.zw;
                float dist = SAMPLE_TEXTURE2D(_DistortTex, sampler_DistortTex, float2(distUV.x + _Time.x, distUV.y));
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + float2(_MainTexUFlowSpeed, _MainTexVFlowSpeed) * _Time.x + i.uv.zw + dist * 0.1) * i.color;
                float dissolve = SAMPLE_TEXTURE2D(_DissolveTex, sampler_DissolveTex,
                                                  i.uv * _DissolveUV.xy + _DissolveUV.zw).r;
                float2 serrationUV = Rotate_Degrees(i.uv * _SerrationUV.xy + _SerrationUV.zw, _SerrationRotate);
                float serration = SAMPLE_TEXTURE2D(_SerrationTex, sampler_SerrationTex,
                                                   serrationUV).r;
                float diss = (dissolve + (1 - i.customData.x * 2));
                float dissolveSoft = clamp(0, 0.5, _DissolveSoft);
                col.a = smoothstep(dissolveSoft, 1 - dissolveSoft, diss) * col.a * serration;
                return float4(col.rgb * _ColorStrength, col.a);
            }
            ENDHLSL
        }
    }
}