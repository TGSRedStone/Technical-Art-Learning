//reference : https://github.com/QianMo/X-PostProcessing-Library/blob/master/Assets/X-PostProcessing/Effects/DirectionalBlur/Shader/DirectionalBlur.shader

Shader "PostProcessing/Blur/DirectionalBlur"
{
	HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
	half3 _Params;	
	#define _Iteration _Params.x
	#define _Direction _Params.yz
    
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
		half4 color = half4(0.0, 0.0, 0.0, 0.0);

		for (int k = -_Iteration; k < _Iteration; k++)
		{
			color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv - _Direction * k);
		}
		half4 finalColor = color / (_Iteration * 2.0);

		return finalColor;
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
