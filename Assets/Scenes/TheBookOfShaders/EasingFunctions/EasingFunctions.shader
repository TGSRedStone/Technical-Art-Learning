Shader "TheBookOfShaders/EasingFunctions"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
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
            };

// Robert Penner's easing functions in GLSL
// https://github.com/stackgl/glsl-easings
            float Linear(float t)
            {
              return t;
            }
            
            float ExponentialIn(float t) {
              return t == 0.0 ? t : pow(2.0, 10.0 * (t - 1.0));
            }
            
            float ExponentialOut(float t) {
              return t == 1.0 ? t : 1.0 - pow(2.0, -10.0 * t);
            }
            
            float ExponentialInOut(float t) {
              return t == 0.0 || t == 1.0
                ? t
                : t < 0.5
                  ? +0.5 * pow(2.0, (20.0 * t) - 10.0)
                  : -0.5 * pow(2.0, 10.0 - (t * 20.0)) + 1.0;
            }
            
            float SineIn(float t) {
              return sin((t - 1.0) * HALF_PI) + 1.0;
            }
            
            float SineOut(float t) {
              return sin(t * HALF_PI);
            }
            
            float SineInOut(float t) {
              return -0.5 * (cos(PI * t) - 1.0);
            }
            
            float QinticIn(float t) {
              return pow(t, 5.0);
            }
            
            float QinticOut(float t) {
              return 1.0 - (pow(t - 1.0, 5.0));
            }
            
            float QinticInOut(float t) {
              return t < 0.5
                ? +16.0 * pow(t, 5.0)
                : -0.5 * pow(2.0 * t - 2.0, 5.0) + 1.0;
            }
            
            float QuarticIn(float t) {
              return pow(t, 4.0);
            }
            
            float QuarticOut(float t) {
              return pow(t - 1.0, 3.0) * (1.0 - t) + 1.0;
            }
            
            float QuarticInOut(float t) {
              return t < 0.5
                ? +8.0 * pow(t, 4.0)
                : -8.0 * pow(t - 1.0, 4.0) + 1.0;
            }
            
            float QuadraticInOut(float t) {
              float p = 2.0 * t * t;
              return t < 0.5 ? p : -p + (4.0 * t) - 1.0;
            }
            
            float QuadraticIn(float t) {
              return t * t;
            }
            
            float QuadraticOut(float t) {
              return -t * (t - 2.0);
            }
            
            float CubicIn(float t) {
              return t * t * t;
            }
            
            float CubicOut(float t) {
              float f = t - 1.0;
              return f * f * f + 1.0;
            }
            
            float CubicInOut(float t) {
              return t < 0.5
                ? 4.0 * t * t * t
                : 0.5 * pow(2.0 * t - 2.0, 3.0) + 1.0;
            }
            
            float ElasticIn(float t) {
              return sin(13.0 * t * HALF_PI) * pow(2.0, 10.0 * (t - 1.0));
            }
            
            float ElasticOut(float t) {
              return sin(-13.0 * (t + 1.0) * HALF_PI) * pow(2.0, -10.0 * t) + 1.0;
            }
            
            float ElasticInOut(float t) {
              return t < 0.5
                ? 0.5 * sin(+13.0 * HALF_PI * 2.0 * t) * pow(2.0, 10.0 * (2.0 * t - 1.0))
                : 0.5 * sin(-13.0 * HALF_PI * ((2.0 * t - 1.0) + 1.0)) * pow(2.0, -10.0 * (2.0 * t - 1.0)) + 1.0;
            }
            
            float CircularIn(float t) {
              return 1.0 - sqrt(1.0 - t * t);
            }
            
            float CircularOut(float t) {
              return sqrt((2.0 - t) * t);
            }
            
            float CircularInOut(float t) {
              return t < 0.5
                ? 0.5 * (1.0 - sqrt(1.0 - 4.0 * t * t))
                : 0.5 * (sqrt((3.0 - 2.0 * t) * (2.0 * t - 1.0)) + 1.0);
            }
            
            float BounceOut(float t) {
              const float a = 4.0 / 11.0;
              const float b = 8.0 / 11.0;
              const float c = 9.0 / 10.0;
            
              const float ca = 4356.0 / 361.0;
              const float cb = 35442.0 / 1805.0;
              const float cc = 16061.0 / 1805.0;
            
              float t2 = t * t;
            
              return t < a
                ? 7.5625 * t2
                : t < b
                  ? 9.075 * t2 - 9.9 * t + 3.4
                  : t < c
                    ? ca * t2 - cb * t + cc
                    : 10.8 * t * t - 20.52 * t + 10.72;
            }
            
            float BounceIn(float t) {
              return 1.0 - BounceOut(1.0 - t);
            }
            
            float BounceInOut(float t) {
              return t < 0.5
                ? 0.5 * (1.0 - BounceOut(1.0 - t * 2.0))
                : 0.5 * BounceOut(t * 2.0 - 1.0) + 0.5;
            }
            
            float BackIn(float t) {
              return pow(t, 3.0) - t * sin(t * PI);
            }
            
            float BackOut(float t) {
              float f = 1.0 - t;
              return 1.0 - (pow(f, 3.0) - f * sin(f * PI));
            }
            
            float BackInOut(float t) {
              float f = t < 0.5
                ? 2.0 * t
                : 1.0 - (2.0 * t - 1.0);
            
              float g = pow(f, 3.0) - f * sin(f * PI);
            
              return t < 0.5
                ? 0.5 * g
                : 0.5 * (1.0 - g) + 0.5;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 colorA = float3(0.149,0.141,0.912);
                float3 colorB = float3(1.000,0.833,0.224);
                float t = _Time.y;
                float pct = CubicInOut(abs(frac(t) * 2 - 1));
                return float4(lerp(colorA, colorB, pct), 1);
            }
            ENDHLSL
        }
    }
}
