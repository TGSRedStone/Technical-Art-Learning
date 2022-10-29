Shader "Sci-Fi/3D-Printing"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
        _GradientColor ("GradientColor", color) = (1, 1, 1, 1)
        _CutY ("CutY", float) = 1
        _GradientLength ("GradientLength", float) = 1
        _Frequency ("Frequency", float) = 60
        _Amplitude ("Amplitude", float) = 120
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        
        cull off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _Color;
            float4 _GradientColor;
            float _CutY;
            float _GradientLength;
            float _Frequency;
            float _Amplitude;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

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
                float3 worldViewDir : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 objPos : TEXCOORD4;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldViewDir = GetCameraPositionWS() - worldPos;
                o.objPos = v.vertex.xyz;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float swing = sin((i.objPos.x * i.objPos.z) * _Frequency + _Time.w) / _Amplitude;
                clip(_CutY - i.objPos.y + swing);
                float mask = step(1, _CutY - i.objPos.y + _GradientLength + swing) * step(0, dot(i.worldNormal, i.worldViewDir));
                float3 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb * _Color.rgb;
                float3 gradientColor = (1 - mask) * _GradientColor.rgb;
                return float4(col + gradientColor, 1);
            }
            ENDHLSL
        }
    }
}
