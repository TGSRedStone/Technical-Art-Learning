Shader "Shaders/BaseURPShader"
{
    Properties
    {}
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            float4 _NearTopLeftPoint;
            float4 _NearXVector;
            float4 _NearYVector;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
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
                float depth = SampleSceneDepth(i.uv);
                float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);

                i.uv.y = 1.0 - i.uv.y;
                float zScale = linearEyeDepth * (1.0 / _ProjectionParams.y);
                float3 viewPos = _NearTopLeftPoint.xyz + _NearXVector.xyz * i.uv.x + _NearYVector.xyz * i.uv.y;
                viewPos *= zScale;

                float3 worldPos = _WorldSpaceCameraPos + viewPos;

                return float4(worldPos, 1);
            }
            ENDHLSL
        }
    }
}
