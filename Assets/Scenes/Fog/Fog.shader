Shader "Hidden/Fog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            float4x4 _MATRIX_I_VP;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

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

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            uniform float _a;
            uniform float _b;
            uniform float3 _fogColor;
            uniform float _startDis;
            uniform float _startHeight;

            float3 applyFog(in float3 rgb, // original color of the pixel
                            in float distance, // camera to point distance
                            in float3 rayOri, // camera position
                            in float3 rayDir,
                            in float3 lightDir) // camera to point vector
            {
                float3 rayOri_pie = rayOri + rayDir * _startDis;
                float c = _a / _b;

                float2 data = float2(-max(0, rayOri_pie.y - _startHeight) * _b,
                                     -max(0, distance - _startDis) * rayDir.y * _b);
                float2 expData = exp(data);
                float opticalThickness = c * expData.x * (1.0 - expData.y) / rayDir.y;
                float extinction = exp(-opticalThickness);
                float fogAmount = 1 - extinction;

                float sunAmount = max(dot(rayDir, lightDir), 0.0);
                float3 fogColor = lerp(float3(0.5, 0.6, 0.7), // blue
                                       float3(1.0, 0.9, 0.7), // yellow
                                       pow(sunAmount, 8.0));

                return lerp(rgb, fogColor, fogAmount);
            }

            float4 frag(v2f i) : SV_Target
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

                float3 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                float3 rayOri = _WorldSpaceCameraPos;
                float3 rayDir = normalize(worldPos.xyz - rayOri);
                float rayDis = length(worldPos.xyz - rayOri);
                float3 lightDir = normalize(_MainLightPosition.xyz);

                float3 fogCol = applyFog(col, rayDis, rayOri, rayDir, lightDir);

                return float4(fogCol, 1);
            }
            ENDHLSL
        }
    }
}