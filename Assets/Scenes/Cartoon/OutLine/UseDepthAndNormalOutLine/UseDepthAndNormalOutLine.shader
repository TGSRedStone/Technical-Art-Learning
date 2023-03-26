Shader "Cartoon/OutLine/UseDepthAndNormalOutLine"
{
	SubShader
    {
        ZTest Always
        ZWrite Off
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            
            float4 _EdgeColor;
            float4 _MainTex_TexelSize;
            float _Scale;
            float _DepthThreshold;
            float _NormalThreshold;
            float4x4 _ClipToView;
            float _DepthNormalThreshold;
			float _DepthNormalThresholdScale;

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 viewSpaceDir : TEXCOORD1;
            };

            float4 alphaBlend(float4 top, float4 bottom)
			{
				float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
				float alpha = top.a + bottom.a * (1 - top.a);

				return float4(color, alpha);
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.viewSpaceDir = mul(_ClipToView, o.vertex).xyz;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float halfScaleFloor = floor(_Scale * 0.5);
				float halfScaleCeil = ceil(_Scale * 0.5);
				
				float2 bottomLeftUV = i.uv - float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleFloor;
				float2 topRightUV = i.uv + float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleCeil;  
				float2 bottomRightUV = i.uv + float2(_MainTex_TexelSize.x * halfScaleCeil, -_MainTex_TexelSize.y * halfScaleFloor);
				float2 topLeftUV = i.uv + float2(-_MainTex_TexelSize.x * halfScaleFloor, _MainTex_TexelSize.y * halfScaleCeil);

            	float depth0 = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomLeftUV).r, _ZBufferParams);
            	float depth1 = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topRightUV).r, _ZBufferParams);
            	float depth2 = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomRightUV).r, _ZBufferParams);
            	float depth3 = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topLeftUV).r, _ZBufferParams);

				float depthFiniteDifference0 = depth1 - depth0;
				float depthFiniteDifference1 = depth3 - depth2;
            	
            	float3 normal0 = SampleSceneNormals(bottomLeftUV);
            	float3 normal1 = SampleSceneNormals(topRightUV);
            	float3 normal2 = SampleSceneNormals(bottomRightUV);
            	float3 normal3 = SampleSceneNormals(topLeftUV);

				float3 normalFiniteDifference0 = normal1 - normal0;
				float3 normalFiniteDifference1 = normal3 - normal2;

				float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2));

				float3 viewNormal = normal0 * 2 - 1;
				float NdotV = 1 - dot(viewNormal, -i.viewSpaceDir);

				float normalThreshold01 = saturate((NdotV - _DepthNormalThreshold) / (1 - _DepthNormalThreshold));
				float normalThreshold = normalThreshold01 * _DepthNormalThresholdScale + 1;
				
				float depthThreshold = _DepthThreshold * depth0 * normalThreshold;
				edgeDepth = edgeDepth > depthThreshold ? 1 : 0;

				float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
				edgeNormal = edgeNormal > _NormalThreshold ? 1 : 0;
				
				float edge = max(edgeDepth, edgeNormal);

				float4 edgeColor = float4(_EdgeColor.rgb, _EdgeColor.a * edge);
				
				float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

				return alphaBlend(edgeColor, color);
            }
            ENDHLSL
        }
    }
}
