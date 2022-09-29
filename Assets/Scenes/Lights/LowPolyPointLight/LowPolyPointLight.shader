Shader "Lights/LowPolyPointLight"
{
    Properties
    {
        _ID ("ID", float) = 1
        _Color ("Color", color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque " "Queue" = "Geometry" "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
            CBUFFER_START(UnityPerMaterial)
            float _ID;
            float4 _Color;
            CBUFFER_END
    
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
    
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }
    
            float4 topFrag (v2f i) : SV_Target
            {
                return float4(0, 0, 0, 1);
            }

            float4 bottomFrag (v2f i) : SV_Target
            {
                return _Color;
            }
        ENDHLSL

        Pass
        {
            Tags{ "LightMode" = "UniversalForward" }
            Stencil
            {
                Ref [_ID]
                Comp Always
                Pass replace
            }
            ZTest Greater
            Zwrite off
            cull front
            colormask 0
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment topFrag

            ENDHLSL
        }
        
        Pass
        {
            Tags{ "LightMode" = "LightweightForward" }
            Blend SrcAlpha One
            Stencil
            {
                Ref [_ID]
                Comp Equal
            }
            ZWrite off
            cull back
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment bottomFrag

            ENDHLSL
        }
    }
}
