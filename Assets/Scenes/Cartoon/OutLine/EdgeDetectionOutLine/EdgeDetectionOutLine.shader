Shader "Cartoon/OutLine/EdgeDetectionOutLine/EdgeDetectionOutLine"
{
    SubShader
    {
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        float4 _OutLineColor;
        float4 _MainTex_TexelSize;
        float _EdgePower;
        float _SampleRange;

        TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

        float Luminance(float3 RGB)
        {
	        return 0.2125 * RGB.r + 0.7154 * RGB.g + 0.0721 * RGB.b;
        }

        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert_Roberts
            #pragma fragment frag_Roberts

            struct v2f
            {
                float2 uvRoberts[5] : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float Roberts(v2f i)
			{
				const float Gx[4] = 
				{
					-1,  0,
					0,  1
				};
				
				const float Gy[4] =
				{
					0, -1,
					1,  0
				};
				
				float edgex = 0, edgey = 0;
				for(int j = 0; j < 4; j++)
				{
					half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uvRoberts[j]);
					float lum = Luminance(col.rgb);
					
					edgex += lum * Gx[j];
					edgey += lum * Gy[j];
				}
				return 1 - abs(edgex) - abs(edgey);
			}

            v2f vert_Roberts (appdata v)
			{
				v2f o;
				o.vertex = TransformObjectToHClip(v.vertex.xyz);
				o.uvRoberts[0] = v.uv + float2(-1, -1) * _MainTex_TexelSize * _SampleRange;
				o.uvRoberts[1] = v.uv + float2( 1, -1) * _MainTex_TexelSize * _SampleRange;
				o.uvRoberts[2] = v.uv + float2(-1,  1) * _MainTex_TexelSize * _SampleRange;
				o.uvRoberts[3] = v.uv + float2( 1,  1) * _MainTex_TexelSize * _SampleRange;
				o.uvRoberts[4] = v.uv;
				return o;
			}
			
			half4 frag_Roberts (v2f i) : SV_Target
			{
				half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uvRoberts[4]);
				float g = Roberts(i);
				g = pow(g, _EdgePower);
				col.rgb = lerp(_OutLineColor.rgb, col.rgb, g);
			
				return col;
			}
        	
        	ENDHLSL
        }
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert_Sobel
            #pragma fragment frag_Sobel

            struct v2f
            {
                float2 uvSobel[9] : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

			float Sobel(v2f i)
			{
				const float Gx[9] = 
				{
					-1, -2, -1,
					0,  0,  0,
					1,  2,  1
				};
				
				const float Gy[9] =
				{
					1, 0, -1,
					2, 0, -2,
					1, 0, -1
				};
				
				float edgex = 0, edgey = 0;
				for(int j = 0; j < 9; j++)
				{
					half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uvSobel[j]);
					float lum = Luminance(col.rgb);
					
					edgex += lum * Gx[j];
					edgey += lum * Gy[j];
				}
				return 1 - abs(edgex) - abs(edgey);
			}

            v2f vert_Sobel (appdata v)
			{
				v2f o;
				o.vertex = TransformObjectToHClip(v.vertex.xyz);
				o.uvSobel[0] = v.uv + float2(-1, -1) * _MainTex_TexelSize * _SampleRange;
				o.uvSobel[1] = v.uv + float2( 0, -1) * _MainTex_TexelSize * _SampleRange;
				o.uvSobel[2] = v.uv + float2( 1, -1) * _MainTex_TexelSize * _SampleRange;
				o.uvSobel[3] = v.uv + float2(-1,  0) * _MainTex_TexelSize * _SampleRange;
				o.uvSobel[4] = v.uv + float2( 0,  0) * _MainTex_TexelSize * _SampleRange;
				o.uvSobel[5] = v.uv + float2( 1,  0) * _MainTex_TexelSize * _SampleRange;
				o.uvSobel[6] = v.uv + float2(-1,  1) * _MainTex_TexelSize * _SampleRange;
				o.uvSobel[7] = v.uv + float2( 0,  1) * _MainTex_TexelSize * _SampleRange;
				o.uvSobel[8] = v.uv + float2( 1,  1) * _MainTex_TexelSize * _SampleRange;
				return o;
			}

			half4 frag_Sobel (v2f i) : SV_Target
			{
				half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uvSobel[4]);
				float g = Sobel(i);
				g = pow(g, _EdgePower);
				col.rgb = lerp(_OutLineColor.rgb, col.rgb, g);
			
				return col;
			}
            
            ENDHLSL
        }
    }
}
