//reference : https://github.com/QianMo/X-PostProcessing-Library/blob/master/Assets/X-PostProcessing/Effects/BoxBlur/Shader/BoxBlur.shader

Shader "PostProcessing/Blur/BoxBlur"
{
	HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
    half4 _BlurOffset;
    float4 _MainTex_TexelSize;
    
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
	
	half4 fragBlur(v2fBlur i) : SV_TARGET
	{
		float4 d = _MainTex_TexelSize.xyxy * _BlurOffset.xyxy * float4(-1.0, -1.0, 1.0, 1.0);
		
		half4 s = 0;
		s = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + d.xy) * 0.25h;  // 1 MUL
		s += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + d.zy) * 0.25h; // 1 MAD
		s += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + d.xw) * 0.25h; // 1 MAD
		s += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + d.zw) * 0.25h; // 1 MAD
		
		return s;
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
