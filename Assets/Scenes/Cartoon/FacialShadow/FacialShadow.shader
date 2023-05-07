Shader "Cartoon/FacialShadow"
{
    Properties
    {
        [NoScaleOffset]_SDF ("SDF", 2d) = "white" {}
        _ForwardVector ("ForwardVector", vector) = (0, 0, 1, 0)
        _RightVector ("RightVector", vector) = (1, 0, 0, 0)
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
            float4 _ForwardVector;
            float4 _RightVector;
            CBUFFER_END

            TEXTURE2D(_SDF); SAMPLER(sampler_SDF);

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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldLight = normalize(_MainLightPosition.xyz);
                float3 forwardVector = _ForwardVector;
                float3 rightVector = _RightVector;
                float3 upVector = cross(forwardVector, rightVector);
                float3 LightProjectionUp = dot(worldLight, upVector) / pow(length(upVector), 2) * upVector;
                float3 LpHeadHorizon = worldLight - LightProjectionUp;
                
                float pi = 3.14159265358979323846;
                float value = acos(dot(normalize(LpHeadHorizon), normalize(rightVector))) / pi;
                float exposeRight = step(value, 0.5);
                
                float valueR = pow(1 - value * 2, 3);
                float valueL = pow(value * 2 - 1, 3);
                float mixValue = lerp(valueL, valueR, exposeRight);
                
                float sdfLeft = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, float2(1 - i.uv.x, i.uv.y)).r;
                float sdfRight = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, i.uv).r;
                float mixSdf = lerp(sdfRight, sdfLeft, exposeRight);
                float sdf = step(mixValue, mixSdf);
                sdf = lerp(0, sdf, step(0, dot(normalize(LpHeadHorizon), normalize(forwardVector))));
                return sdf;
            }
            ENDHLSL
        }
    }
}
