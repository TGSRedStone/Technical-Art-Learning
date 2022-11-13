Shader "TheBookOfShaders/Shapes/SDF3"
{
    Properties
    {
        _Resolution ("Resolution", float) = 1
        _a ("a", float) = 0
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
            float _Resolution;
            float _a;
            CBUFFER_END

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
                float2 uv = i.uv * _Resolution;
                uv += float2(cos(_Time.z * 0.3) , sin(_Time.z * 2)) * 0.2;
                float2 pos = 0.5 - uv;

                float r = length(pos) * _a;
                //TODO: 这句还有问题，每个周期会抽动一次
                float a = atan2(pos.y, pos.x) + frac(_Time.y / 2) * 8 - 4;
// return a;
                float f = cos(a * 3);
                f = abs(cos(a * 3.0));
                // f = abs(cos(a * 2.5)) * 0.5 + 0.3;
                // f = abs(cos(a * 12.0) * sin(a * 3.0)) * 0.8 + 0.1;
                // f = smoothstep(-0.5, 1.0, cos(a * 10.0)) * 0.2 + 0.5;
                // return r;
                f = abs(sin(a * 5) * sin(a * 5)) * 0.7 + 0.2;
                return 1 - smoothstep(f, f + 0.02, r);
            }
            ENDHLSL
        }
    }
}
