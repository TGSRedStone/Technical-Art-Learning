Shader "Tool/Noise/WorleyNoise"
{
    Properties
    {
        _Resolution ("Resolution", float) = 1
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

            float2 randPos(float2 value)
			{
				float2 pos = float2(dot(value, float2(127.1, 337.1)), dot(value, float2(269.5, 183.3)));
				pos = frac(sin(pos) * 43758.5453123);
				return pos;
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float WorleyNoise(float2 uv)
			{
				float2 index = floor(uv);
				float2 pos = frac(uv);
				float d = 1.5;
				for(int i = -1; i < 2; i++)
					for (int j = -1; j < 2; j++)
					{
						float2 p = randPos(index + float2(i, j));
						p = cos(_Time.y + 6.2831 * p) * 0.5 + 0.5;//动态
						float dist = length(p + float2(i, j) - pos);
						d = min(dist, d);
					}
				return d;
			}

            float4 frag (v2f i) : SV_Target
            {
            	i.uv *= _Resolution;
                float d = WorleyNoise(i.uv);
                return d;
            }
            ENDHLSL
        }
    }
}
