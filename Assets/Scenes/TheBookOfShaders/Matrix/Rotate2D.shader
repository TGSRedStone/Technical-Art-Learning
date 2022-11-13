Shader "TheBookOfShaders/Matrix/Rotate2D"
{
    Properties
    {
        _a ("a", float) = 1
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

            float2x2 Rotate2d(float angle)
            {
                return float2x2(cos(angle), -sin(angle), sin(angle), cos(angle));
            }

            float box(in float2 _st, in float2 _size)
            {
                _size = 0.5 - _size * 0.5;
                float2 uv = smoothstep(_size, _size + 0.001, _st);
                uv *= smoothstep(_size, _size + 0.001, 1.0 - _st);
                return uv.x * uv.y;
            }
            
            float cross(in float2 _st, float _size){
                return  box(_st, float2(_size, _size / 4.0)) + box(_st, float2(_size / 4.0, _size));
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
                float3 col = 0;
                float2 uv = i.uv;
                uv -= 0.5;
                uv = mul(uv, Rotate2d(sin(_Time.y) * PI));
                uv += 0.5;

                col = float3(uv.x, uv.y, 0);

                col += cross(uv, _a);
                
                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}
