Shader "Else/ReBuildWoldPos/UseDepthTexReBuildWoldPos"
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

            float4x4 _MATRIX_I_VP;

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
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(i.uv);
                #else
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
                #endif

                float4 positionCS = float4(i.uv * 2 - 1, depth, 1);

                #if UNITY_UV_STARTS_AT_TOP
                    positionCS.y = -positionCS.y;
                #endif
                float4 worldPos = mul(_MATRIX_I_VP, positionCS);
                worldPos /= worldPos.w;
                //float3 worldPos = ComputeWorldSpacePosition(i.uv, depth, UNITY_MATRIX_I_VP);

                return float4(worldPos.xyz, 1);
            }
            ENDHLSL
        }
    }
}
