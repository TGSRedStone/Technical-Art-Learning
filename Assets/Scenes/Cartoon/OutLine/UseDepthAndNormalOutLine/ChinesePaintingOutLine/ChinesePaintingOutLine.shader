Shader "Cartoon/OutLine/ChinesePaintingOutLine"
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
            float _NoiseTiling;
            float _OutLineWidth;

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
            	float3 viewVec : TEXCOORD02;
            };

            float4 alphaBlend(float4 top, float4 bottom)
			{
				float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
				float alpha = top.a + bottom.a * (1 - top.a);

				return float4(color, alpha);
			}

            #define NOISE_SIMPLEX_1_DIV_289 0.00346020761245674740484429065744f

            float mod289(float x) {
                return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
            }
             
            float2 mod289(float2 x) {
                return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
            }
             
            float3 mod289(float3 x) {
                return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
            }
             
            float4 mod289(float4 x) {
                return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
            }
             
             
            // ( x*34.0 + 1.0 )*x =
            // x*x*34.0 + x
            float permute(float x) {
                return mod289(
                    x*x*34.0 + x
                );
            }
             
            float3 permute(float3 x) {
                return mod289(
                    x*x*34.0 + x
                );
            }
             
            float4 permute(float4 x) {
                return mod289(
                    x*x*34.0 + x
                );
            }
             
             
             
            float taylorInvSqrt(float r) {
                return 1.79284291400159 - 0.85373472095314 * r;
            }
             
            float4 taylorInvSqrt(float4 r) {
                return 1.79284291400159 - 0.85373472095314 * r;
            }
             
            // ----------------------------------- 3D -------------------------------------
             
            float snoise(float3 v)
            {
                const float2 C = float2(
                    0.166666666666666667, // 1/6
                    0.333333333333333333  // 1/3
                );
                const float4 D = float4(0.0, 0.5, 1.0, 2.0);
             
            // First corner
                float3 i = floor( v + dot(v, C.yyy) );
                float3 x0 = v - i + dot(i, C.xxx);
             
            // Other corners
                float3 g = step(x0.yzx, x0.xyz);
                float3 l = 1 - g;
                float3 i1 = min(g.xyz, l.zxy);
                float3 i2 = max(g.xyz, l.zxy);
             
                float3 x1 = x0 - i1 + C.xxx;
                float3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
                float3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y
             
            // Permutations
                i = mod289(i);
                float4 p = permute(
                    permute(
                        permute(
                                i.z + float4(0.0, i1.z, i2.z, 1.0 )
                        ) + i.y + float4(0.0, i1.y, i2.y, 1.0 )
                    )     + i.x + float4(0.0, i1.x, i2.x, 1.0 )
                );
             
            // Gradients: 7x7 points over a square, mapped onto an octahedron.
            // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
                float n_ = 0.142857142857; // 1/7
                float3 ns = n_ * D.wyz - D.xzx;
             
                float4 j = p - 49.0 * floor(p * ns.z * ns.z); // mod(p,7*7)
             
                float4 x_ = floor(j * ns.z);
                float4 y_ = floor(j - 7.0 * x_ ); // mod(j,N)
             
                float4 x = x_ *ns.x + ns.yyyy;
                float4 y = y_ *ns.x + ns.yyyy;
                float4 h = 1.0 - abs(x) - abs(y);
             
                float4 b0 = float4( x.xy, y.xy );
                float4 b1 = float4( x.zw, y.zw );
             
                //float4 s0 = float4(lessThan(b0,0.0))*2.0 - 1.0;
                //float4 s1 = float4(lessThan(b1,0.0))*2.0 - 1.0;
                float4 s0 = floor(b0)*2.0 + 1.0;
                float4 s1 = floor(b1)*2.0 + 1.0;
                float4 sh = -step(h, 0.0);
             
                float4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
                float4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;
             
                float3 p0 = float3(a0.xy,h.x);
                float3 p1 = float3(a0.zw,h.y);
                float3 p2 = float3(a1.xy,h.z);
                float3 p3 = float3(a1.zw,h.w);
             
            //Normalise gradients
                float4 norm = taylorInvSqrt(float4(
                    dot(p0, p0),
                    dot(p1, p1),
                    dot(p2, p2),
                    dot(p3, p3)
                ));
                p0 *= norm.x;
                p1 *= norm.y;
                p2 *= norm.z;
                p3 *= norm.w;
             
            // Mix final noise value
                float4 m = max(
                    0.6 - float4(
                        dot(x0, x0),
                        dot(x1, x1),
                        dot(x2, x2),
                        dot(x3, x3)
                    ),
                    0.0
                );
                m = m * m;
                return 42.0 * dot(
                    m*m,
                    float4(
                        dot(p0, x0),
                        dot(p1, x1),
                        dot(p2, x2),
                        dot(p3, x3)
                    )
                );
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.viewSpaceDir = mul(_ClipToView, o.vertex).xyz;

            	float3 ndcPos = float3(o.uv.xy * 2.0 - 1.0, 1);
				float far = _ProjectionParams.z; //获取投影信息的z值，代表远平面长度
				float3 clipVec = float3(ndcPos.x, ndcPos.y, ndcPos.z * -1) * far;
				o.viewVec = mul(unity_CameraInvProjection, clipVec.xyzz).xyz; //由裁切空间坐标转到观察空间坐标
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
            	float3 worldPos = float3(1,0,0);
            	
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
            	float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv).r, _ZBufferParams);

				float3 viewPos = i.viewVec * depth; //获取实际的观察空间坐标（插值后）
				worldPos = mul(unity_CameraToWorld, float4(viewPos,1)).xyz; //观察空间-->世界空间坐标
                float noise = snoise(worldPos * _NoiseTiling);

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
				edgeDepth = edgeDepth > depthThreshold ? noise : 0;

				float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
            	
				edgeNormal = edgeNormal > _NormalThreshold ? noise : 0;
				
				float edge = max(edgeDepth, edgeNormal);

                edge = pow(abs(edge), _OutLineWidth + 0.0001);

				float4 edgeColor = float4(_EdgeColor.rgb, _EdgeColor.a * edge);

				float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

				return alphaBlend(edgeColor, color);
            }
            ENDHLSL
        }
    }
}
