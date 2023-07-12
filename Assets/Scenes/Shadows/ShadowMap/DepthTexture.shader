Shader "Shadows/ShadowMap/DepthTexture"
{
    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                return o;
            }

            inline float4 EncodeFloatRGBA(float v)
            {
                float vi = (uint)(v * (256.0f * 256.0f * 256.0f * 256.0f));
                float ex = (int)(vi / (256 * 256 * 256) % 256);
                float ey = (int)((vi / (256 * 256)) % 256);
                float ez = (int)((vi / (256)) % 256);
                float ew = (int)(vi % 256);
                float4 e = float4(ex / 255.0f, ey / 255.0f, ez / 255.0f, ew / 255.0f);
                return e;
            }

            inline float4 UnityEncodeFloatRGBA( float v )
            {
                float4 kEncodeMul = float4(1.0, 255.0, 65025.0, 16581375.0);
                float kEncodeBit = 1.0/255.0;
                float4 enc = kEncodeMul * v;
                enc = frac (enc);
                enc -= enc.yzww * kEncodeBit;
                return enc;
            }

            float4 frag (v2f i) : SV_Target
            {
                float depth = i.vertex.z / i.vertex.w;

                #if defined(SHADER_TARGET_GLSL)
                    depth = depth * 0.5 + 0.5;
                #elif defined(UNITY_REVERSED_Z)
                    depth = 1 - depth;
                #endif
                
                // return UnityEncodeFloatRGBA(depth);
                return depth;
            }
            ENDHLSL
        }
    }
}
