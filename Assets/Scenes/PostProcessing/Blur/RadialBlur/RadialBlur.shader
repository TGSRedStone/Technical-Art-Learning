//reference : https://github.com/QianMo/X-PostProcessing-Library/blob/master/Assets/X-PostProcessing/Effects/RadialBlur/Shader/RadialBlur.shader

Shader "PostProcessing/Blur/RadialBlur"
{
	HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
	half4 _Params;
	#define _BlurRadius _Params.x
	#define _Iteration _Params.y
	#define _RadialCenter _Params.zw
    
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
		float2 blurVector = (_RadialCenter - i.uv.xy) * _BlurRadius;
		
		half4 acumulateColor = half4(0, 0, 0, 0);
		
		[unroll(30)]
		for (int j = 0; j < _Iteration; j ++)
		{
			acumulateColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
			i.uv.xy += blurVector;
		}
		
		return acumulateColor / _Iteration;
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
