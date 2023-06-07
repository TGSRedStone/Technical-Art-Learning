Shader "Else/InteractiveMask"
{
    Properties
    {
        _ObjWorldPos ("ObjWorldPos", vector) = (0, 0, 0, 0)
        _Radius ("Radius", float) = 0.1
        _TopDownRadius ("TopDownRadius", float) = 0.1
        _EdgeSmooth ("EdgeSmooth", float) = 0.1
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"}
        
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _ObjWorldPos;
            float _Radius;
            float _TopDownRadius;
            float _EdgeSmooth;
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
                float3 worldPos : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float posMask = distance(_ObjWorldPos.xyz, i.worldPos) - _Radius;
                float topDownMask = (distance(_ObjWorldPos.xz, i.worldPos.xz) - _TopDownRadius);
                float mask = saturate(lerp(posMask, topDownMask, step(i.worldPos.y, _ObjWorldPos.y)));
                mask = smoothstep(0, _EdgeSmooth, mask);
                return mask;
            }
            ENDHLSL
        }
    }
}
