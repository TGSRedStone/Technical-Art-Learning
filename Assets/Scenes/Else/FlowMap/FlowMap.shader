Shader "Else/FlowMap"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        [NoScaleOffset] _FlowMap ("Flow (RG)", 2D) = "black" {}
        [NoScaleOffset] _Noise ("Noise", 2D) = "black" {}
        _Color ("Color", color) = (1, 1, 1, 1)
        _Speed ("Speed", float) = 1
        _FlowStrength ("Flow Strength", Float) = 1
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
            float4 _Color;
            float _FlowStrength;
            float _Speed;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_FlowMap); SAMPLER(sampler_FlowMap);
            TEXTURE2D(_Noise); SAMPLER(sampler_Noise);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float3 FlowUVW (float2 uv, float2 flowVector, float time, bool flowB)
            {
                float phaseOffset = flowB ? 0.5 : 0;
            	float progress = frac(time + phaseOffset);
	            float3 uvw;
	            uvw.xy = uv - flowVector * progress + phaseOffset;
	            uvw.z = 1 - abs(1 - 2 * progress);
	            return uvw;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 flowVector = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, i.uv).rg * 2 - 1;
                float noise = SAMPLE_TEXTURE2D(_Noise, sampler_Noise, i.uv).r;
			    float time = _Time.y * _Speed + noise;
                float3 uvwA = FlowUVW(i.uv, flowVector, time, false);
			    float3 uvwB = FlowUVW(i.uv, flowVector, time, true);
                float4 colA = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvwA.xy) * uvwA.z * _Color;
                float4 colB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvwB.xy) * uvwB.z * _Color;
                return colA + colB;
            }
            ENDHLSL
        }
    }
}
