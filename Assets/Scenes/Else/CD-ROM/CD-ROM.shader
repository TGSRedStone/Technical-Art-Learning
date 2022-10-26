Shader "Else/CD-ROM"
{
    Properties
    {
        _Distance ("Distance", Range(0,10000)) = 1600
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
            float _Distance;
            CBUFFER_END

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
                float3 worldNormal : TEXCOORD1;
                float3 worldViewDir : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldViewDir = GetCameraPositionWS() - worldPos;
                return o;
            }

            float3 bump3y (float3 x, float3 yoffset)
            {
            	float3 y = float3(1.,1.,1.) - x * x;
            	y = saturate(y-yoffset);
            	return y;
            }

            float3 spectral_zucconi6 (float w)
            {
            	// w: [400, 700]
            	// x: [0,   1]
            	float x = saturate((w - 400.0)/ 300.0);
            
            	const float3 c1 = float3(3.54585104, 2.93225262, 2.41593945);
            	const float3 x1 = float3(0.69549072, 0.49228336, 0.27699880);
            	const float3 y1 = float3(0.02312639, 0.15225084, 0.52607955);
            
            	const float3 c2 = float3(3.90307140, 3.21182957, 3.96587128);
            	const float3 x2 = float3(0.11748627, 0.86755042, 0.66077860);
            	const float3 y2 = float3(0.84897130, 0.88445281, 0.73949448);
            
            	return bump3y(c1 * (x - x1), y1) + bump3y(c2 * (x - x2), y2);
            }

            float4 frag (v2f i) : SV_Target
            {
                half2 uv = i.uv * 2 -1;
                half2 uv_orthogonal = normalize(uv);
                half3 uv_tangent = half3(-uv_orthogonal.y, 0, uv_orthogonal.x);
                float3 T = normalize(mul((float3x3)unity_ObjectToWorld, uv_tangent));
                
                float3 L = normalize(_MainLightPosition.xyz);
                float3 V = normalize(i.worldViewDir);

                float cosL = dot(L, T);
                float cosV = dot(V, T);
                float u = abs(cosL - cosV);

                half3 col = 0;
                
                for (int n = 1; n <= 8; n++)
                {
                    float waveLength = u * _Distance / n;
                    col += spectral_zucconi6(waveLength);
                }
                
                col = saturate(col);

                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}
