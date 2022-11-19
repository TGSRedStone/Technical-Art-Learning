//reference : https://zhuanlan.zhihu.com/p/431384101
//reference : http://www.iryoku.com/aacourse/
//reference : https://github.com/Raphael2048/AntiAliasing/tree/main/Assets
Shader "Shaders/BaseURPShader"
{
    SubShader
    {
	    Cull Off
		ZTest Always
		ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float _ContrastThreshold, _RelativeThreshold;
            float4 _MainTex_TexelSize;

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

            float Luminance(float4 col)
            {
                return 0.2125 * col.r + 0.7154 * col.g + 0.0721 * col.b;
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
                float2 uv = i.uv;
                float2 TexelSize = _MainTex_TexelSize.xy;
                float4 origin = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float M = Luminance(origin);
                float E = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(TexelSize.x, 0)));
                float N = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(0, TexelSize.y)));
                float W = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-TexelSize.x, 0)));
                float S = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(0, -TexelSize.y)));
                float NW = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-TexelSize.x, TexelSize.y)));
                float NE = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(TexelSize.x, TexelSize.y)));
                float SW = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-TexelSize.x, -TexelSize.y)));
                float SE = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(TexelSize.x, -TexelSize.y)));

                float MaxLuma = max(max(max(N, E), max(W, S)), M);
                float MinLuma = min(min(min(N, E), min(W, S)), M);
                float Contrast = MaxLuma - MinLuma;

                if(Contrast < max(_ContrastThreshold, MaxLuma * _RelativeThreshold))
                {
                    return origin;
                }

                // 先计算出锯齿的方向，是水平还是垂直方向
				float Vertical   = abs(N + S - 2 * M) * 2 + abs(NE + SE - 2 * E) + abs(NW + SW - 2 * W);
				float Horizontal = abs(E + W - 2 * M) * 2 + abs(NE + NW - 2 * N) + abs(SE + SW - 2 * S);
				bool IsHorizontal = Vertical > Horizontal;
				//混合的方向
				float2 PixelStep = IsHorizontal ? float2(0, TexelSize.y) : float2(TexelSize.x, 0);
				// 确定混合方向的正负值
				float Positive = abs((IsHorizontal ? N : E) - M);
				float Negative = abs((IsHorizontal ? S : W) - M);
				// if(Positive < Negative) PixelStep = -PixelStep;
				// 算出锯齿两侧的亮度变化的梯度值
				float Gradient, OppositeLuminance;
				if(Positive > Negative)
				{
				    Gradient = Positive;
				    OppositeLuminance = IsHorizontal ? N : E;
				}
            	else
            	{
				    PixelStep = -PixelStep;
				    Gradient = Negative;
				    OppositeLuminance = IsHorizontal ? S : W;
				}
	
				// 这部分是基于亮度的混合系数计算
				float Filter = 2 * (N + E + S + W) + NE + NW + SE + SW;
				Filter = Filter / 12;
				Filter = abs(Filter -  M);
				Filter = saturate(Filter / Contrast);
				// 基于亮度的混合系数值
				float PixelBlend = smoothstep(0, 1, Filter);
				PixelBlend = PixelBlend * PixelBlend;
				
				// 下面是基于边界的混合系数计算
				float2 UVEdge = uv;
				UVEdge += PixelStep * 0.5f;
				float2 EdgeStep = IsHorizontal ? float2(TexelSize.x, 0) : float2(0, TexelSize.y);
	
				// 这里是定义搜索的步长，步长越长，效果自然越好
				#define _SearchSteps 15
				// 未搜索到边界时，猜测的边界距离
				#define _Guess 8
	
				// 沿着锯齿边界两侧，进行搜索，找到锯齿的边界
				float EdgeLuminance = (M + OppositeLuminance) * 0.5f;
				float GradientThreshold = Gradient * 0.25f;
				float PLuminanceDelta, NLuminanceDelta, PDistance, NDistance;

            	int x;
				UNITY_UNROLL
				for(x = 1; x <= _SearchSteps; ++x)
				{
				    PLuminanceDelta = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UVEdge + x * EdgeStep)) - EdgeLuminance;
				    if(abs(PLuminanceDelta) > GradientThreshold)
				    {
				        PDistance = x * (IsHorizontal ? EdgeStep.x : EdgeStep.y);
				        break;
				    }
				}
				if(x == _SearchSteps + 1)
            	{
				    // PDistance = EdgeStep * _Guess;
				    PDistance = (IsHorizontal ? EdgeStep.x : EdgeStep.y) * _Guess;
				}
            	
				UNITY_UNROLL
				for(x = 1; x <= _SearchSteps; ++x)
				{
				    NLuminanceDelta = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UVEdge - x * EdgeStep)) - EdgeLuminance;
				    if(abs(NLuminanceDelta) > GradientThreshold)
				    {
				        NDistance = x * (IsHorizontal ? EdgeStep.x : EdgeStep.y);
				        break;
				    }
				}
				if(x == _SearchSteps + 1)
				{
				    // NDistance = EdgeStep * _Guess;
				    NDistance = (IsHorizontal ? EdgeStep.x : EdgeStep.y) * _Guess;
				}
	
				float EdgeBlend;
				// 这里是计算基于边界的混合系数，如果边界方向错误，直接设为0，如果方向正确，按照相对的距离来估算混合系数
				if (PDistance < NDistance)
				{
					if(sign(PLuminanceDelta) == sign(M - EdgeLuminance))
					{
				        EdgeBlend = 0;
				    }
					else
				    {
				        EdgeBlend = 0.5f - PDistance / (PDistance + NDistance);
				    }
				}
            	else
            	{
				    if(sign(NLuminanceDelta) == sign(M - EdgeLuminance))
				    {
				        EdgeBlend = 0;
				    }
            		else
				    {
				        EdgeBlend = 0.5f - NDistance / (PDistance + NDistance);
				    }
				}
	
				//从两种混合系数中，取最大的那个
				float FinalBlend = max(PixelBlend, EdgeBlend);
				float4 Result = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + PixelStep * FinalBlend);
				return Result;
            }
            ENDHLSL
        }
    }
	FallBack off
}
