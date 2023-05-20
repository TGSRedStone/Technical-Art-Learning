Shader "Else/StippleTransparency/StippleTransparencyWithDistance"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
        _Near ("Near", float) = 1
        _Far ("Far", float) = 10
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
            float4 _MainTex_ST;
            float4 _Color;
            float _Alpha;
            float _Near;
            float _Far;
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
                float4 screenPos : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(o.vertex);
                o.worldPos = TransformObjectToWorld(o.vertex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float DistanceRamp = distance(i.worldPos, _WorldSpaceCameraPos.xyz);
                DistanceRamp = smoothstep(_Near, _Far, DistanceRamp);
                //https://digitalrune.github.io/DigitalRune-Documentation/html/fa431d48-b457-4c70-a590-d44b0840ab1e.htm
                /*With 4 x 4 threshold values, it is possible to create 17 states: visible, invisible, and 15 patterns in between. The result is shown in the image above.
                //The threshold matrix used in this example is the same matrix as used by ordered dithering [1]. It is also known as index matrix or Bayer matrix. Dither
                //matrices are nice because they create regular patterns. But in theory, any random permutation of threshold values should do.
                //To create more states, we need bigger matrices. For example, with 16 x 16 threshold values we can create 257 states. (To create a regular 16 x 16 dither pattern,
                the information in [2] and the corresponding code example [3] can be very helpful.)*/
                float4x4 thresholdMatrix =
                {  1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
                  13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
                   4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
                  16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
                };
                float4x4 _RowAccess = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
                float2 pos = i.screenPos.xy / i.screenPos.w;
                pos *= _ScreenParams.xy;
                //高度渐变
			    //float HightRamp = 1 - smoothstep(_FogLow, _FogHight, i.WordPos.y);
			    //保留地面
			    //DistanceRamp = saturate( DistanceRamp + HightRamp);
                clip(_Color.a * DistanceRamp - thresholdMatrix[fmod(pos.x, 4)] * _RowAccess[fmod(pos.y, 4)]);
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                col *= pow(DistanceRamp, 5);
                return col;
            }
            ENDHLSL
        }
    }
}
