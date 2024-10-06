Shader "Cartoon/OutLine/RenderObjectOutLine"
{
    Properties
    {
        _OutLineColor ("_OutLineColor", color) = (1, 1, 1, 1)
        _OutlineWidth ("OutlineWidth", float) = 2
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        
        cull front

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _OutLineColor;
                float _OutlineWidth;
            CBUFFER_END

            struct appdata
            {
                float4 vertex : POSITION;
                float4 tangent : TANGENT;
                float3 normal : NORMAL;
                float4 uv7 : TEXCOORD7;
            };

            struct v2f
            {
                float4 clipPos : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs vpi = GetVertexPositionInputs(v.vertex.xyz += v.tangent.xyz * 0.01 * _OutlineWidth);
                // VertexPositionInputs vpi = GetVertexPositionInputs(v.vertex.xyz);
                VertexNormalInputs vni = GetVertexNormalInputs(v.normal, v.tangent);

                // float3 worldPos = vpi.positionWS;
                // float3x3 tbn = float3x3(vni.tangentWS, vni.bitangentWS, vni.normalWS);
                // worldPos += mul(v.uv7.rgb , tbn) * 0.01 * _OutlineWidth;
                // o.clipPos = TransformWorldToHClip(worldPos);
                o.clipPos = vpi.positionCS;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = float4(_OutLineColor.rgb, 1);

                return col;
            }
            ENDHLSL
        }
    }
}
