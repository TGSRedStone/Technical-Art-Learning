Shader "NoteEffect/HoldVFX"
{
    Properties
    {
        _LineCount ("频谱条数", int) = 10
        _Interval ("频谱间隔", float) = 0.8
        _Frequency ("频率", int) = 10
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            cull Off
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                int _LineCount;
                int _Frequency;
                float _Interval;
            CBUFFER_END

            float hash11(float p)
            {
                p = frac(p * .1031);
                p *= p + 33.33;
                p *= p + p;
                return frac(p);
            }

            float2 randVec(float2 value)
			{
				float2 vec = float2(dot(value, float2(127.1, 337.1)), dot(value, float2(269.5, 183.3)));
				vec = -1 + 2 * frac(sin(vec) * 43758.5453123);
				return vec;
			}

            float perlinNoise(float2 uv)
			{
				float a, b, c, d;
				float x0 = floor(uv.x);
				float x1 = ceil(uv.x);
				float y0 = floor(uv.y);
				float y1 = ceil(uv.y);
				float2 pos = frac(uv);
				a = dot(randVec(float2(x0, y0)), pos - float2(0, 0));
				b = dot(randVec(float2(x0, y1)), pos - float2(0, 1));
				c = dot(randVec(float2(x1, y1)), pos - float2(1, 1));
				d = dot(randVec(float2(x1, y0)), pos - float2(1, 0));
				float2 st = 6 * pow(pos, 5) - 15 * pow(pos, 4) + 10 * pow(pos, 3);
				a = lerp(a, d, st.x);
				b = lerp(b, c, st.x);
				a = lerp(a, b, st.y);
				return a;
			}

            half remap(half x, half t1, half t2, half s1, half s2)
            {
                return (x - t1) / (t2 - t1) * (s2 - s1) + s1;
            }

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

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float x = 256 / _LineCount;
                x = floor(i.uv.x * x) / x;
                float interval = step(frac(i.uv.x * _LineCount), _Interval);
                x = x + _Time.x;
                x = perlinNoise(x * 15);
                float t = sin(_Time.x * _Frequency);
                t = remap(t, -1, 1, 0.5, 1);
                float alpha = (1 - i.uv.y) - x * t;
                alpha = step(alpha, 0.8);
                return 1 - alpha;
            }
            ENDHLSL
        }
    }
}
