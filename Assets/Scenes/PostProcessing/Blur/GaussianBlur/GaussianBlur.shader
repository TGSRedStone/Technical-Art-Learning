//reference : https://github.com/QianMo/X-PostProcessing-Library/blob/master/Assets/X-PostProcessing/Effects/GaussianBlur/Shader/GaussianBlur.shader

Shader "PostProcessing/Blur/GaussianBlur"
{
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
    half4 _BlurSize;
    
    TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
    
    struct a2vBlur
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };
    
    struct v2fBlur
    {
        float4 pos : SV_POSITION;
        half2 uv : TEXCOORD0;
        float4 uv01: TEXCOORD1;
		float4 uv23: TEXCOORD2;
		float4 uv45: TEXCOORD3;
    };
    
    v2fBlur vertBlur(a2vBlur v)
    {
        v2fBlur o;
        o.pos = TransformObjectToHClip(v.vertex.xyz);
        o.uv = v.uv;
        o.uv01 = o.uv.xyxy + _BlurSize.xyxy * float4(1, 1, -1, -1);
		o.uv23 = o.uv.xyxy + _BlurSize.xyxy * float4(1, 1, -1, -1) * 2.0;
		o.uv45 = o.uv.xyxy + _BlurSize.xyxy * float4(1, 1, -1, -1) * 6.0;
        return o;
    }
    
    half4 fragBlur(v2fBlur i) : SV_TARGET
    {
        half4 color = float4(0, 0, 0, 0);
		
		color += 0.40 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
		color += 0.15 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.xy);
		color += 0.15 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.zw);
		color += 0.10 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.xy);
		color += 0.10 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.zw);
		color += 0.05 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv45.xy);
		color += 0.05 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv45.zw);
		
		return color;
    }
    ENDHLSL
    
    SubShader
    {
        ZTest Always
        ZWrite Off
        Cull Off
        
        pass
        {
            HLSLPROGRAM
            #pragma vertex vertBlur
            #pragma fragment fragBlur
            ENDHLSL
        }
    }
    Fallback Off
}
