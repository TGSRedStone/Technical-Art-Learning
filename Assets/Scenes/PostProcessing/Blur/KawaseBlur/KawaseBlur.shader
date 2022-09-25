Shader "PostProcessing/Blur/KawaseBlur"
{
	HLSLINCLUDE 
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
    float4 _MainTex_TexelSize;
    half _PixelOffset;
    
    TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
    
    struct a2vBlur
    {
        float4 vertex : POSITION;
    	float2 uv : TEXCOORD0;
    };
    
    struct v2fBlur
    {
        float4 pos : SV_POSITION;
    	float2 uv : TEXCOORD0;
    };
    
	v2fBlur vertBlur(a2vBlur v)
    {
        v2fBlur o;
        o.pos = TransformObjectToHClip(v.vertex.xyz);
		o.uv = v.uv;
        return o;
    }

	half4 KawaseBlur(float2 uv)
    {
        half4 o = 0;
        o += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(_PixelOffset + 0.5, _PixelOffset + 0.5) * _MainTex_TexelSize.xy); 
        o += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-_PixelOffset - 0.5, _PixelOffset + 0.5) * _MainTex_TexelSize.xy); 
        o += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-_PixelOffset - 0.5, -_PixelOffset - 0.5) * _MainTex_TexelSize.xy); 
        o += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(_PixelOffset + 0.5, -_PixelOffset - 0.5) * _MainTex_TexelSize.xy); 
        return o * 0.25;
    }

	half4 fragBlur(v2fBlur i) : SV_TARGET
	{
		return KawaseBlur(i.uv);
	}
    
    ENDHLSL
	
	SubShader
	{
       	ZTest Always
       	ZWrite Off
       	Cull Off
       	
       	Pass
		{
			HLSLPROGRAM
			
			#pragma vertex vertBlur
			#pragma fragment fragBlur
			
			ENDHLSL
			
		}
    }
    Fallback Off
}
