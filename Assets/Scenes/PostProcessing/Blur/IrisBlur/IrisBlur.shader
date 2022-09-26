//reference : https://github.com/QianMo/X-PostProcessing-Library/blob/master/Assets/X-PostProcessing/Effects/IrisBlurV2/Shader/IrisBlurV2.shader

Shader "PostProcessing/Blur/IrisBlur"
{
    HLSLINCLUDE
    
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

	half3 _Gradient;
	half4 _GoldenRot;
	half4 _Params;
	
	#define _Offset _Gradient.xy
	#define _AreaSize _Gradient.z
	#define _Iteration _Params.x
	#define _Radius _Params.y
	#define _PixelSize _Params.zw
    
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

    float IrisMask(float2 uv)
	{
	    float2 center = uv * 2.0 - 1.0 + _Offset; // [0,1] -> [-1,1] 
	    return dot(center, center) * _AreaSize;
	}
    
	v2fBlur vertBlur(a2vBlur v)
    {
        v2fBlur o;
        o.pos = TransformObjectToHClip(v.vertex.xyz);
		o.uv = v.uv;
        return o;
    }
	
	half4 fragBlur(v2fBlur i) : SV_TARGET
    {
        half2x2 rot = half2x2(_GoldenRot);
        half4 accumulator = 0.0;
        half4 divisor = 0.0;
    
        half r = 1.0;
        half2 angle = half2(0.0, _Radius * saturate(IrisMask(i.uv)));
    
        for (int j = 0; j < _Iteration; j++)
        {
            r += 1.0 / r;
            angle = mul(rot, angle);
            half4 bokeh = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(i.uv + _PixelSize * (r - 1.0) * angle));
            accumulator += bokeh * bokeh;
            divisor += bokeh;
        }
        return accumulator / divisor;
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
