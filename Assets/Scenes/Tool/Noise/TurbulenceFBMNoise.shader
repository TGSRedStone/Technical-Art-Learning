Shader "Tool/Noise/TurbulenceFBMNoise"
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

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

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
            
            #define OCTAVES 10
            float fbm(float2 st)
            {
                // Initial values
                float value = 0.0;
                float amplitude = .5;
                float frequency = 0.;
                //
                // Loop of octaves
                for (int i = 0; i < OCTAVES; i++)
                {
                    value += amplitude * abs(perlinNoise(st));
                    st *= 2.;
                    amplitude *= .5;
                }
                return value;
            }
   //
   //          float pattern(float2 uv, out float2 q, out float2 r)
			// {
			// 	q = float2(fbm(uv + float2(0.0, 0.0)),
			// 		fbm(uv + float2(5.2, 1.3) * _Time.x));
   //
			// 	r = float2(fbm(uv + 4 * q + float2(1.7, 9.2) * _Time.x),
			// 		fbm(uv + 4 * q + float2(8.3, 2.8) * _Time.x));
   //
			// 	return fbm(uv + 4 * r);
			// }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
            	i.uv *= _Resolution;
                float3 col = 0;
                col += fbm(i.uv);
                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}
