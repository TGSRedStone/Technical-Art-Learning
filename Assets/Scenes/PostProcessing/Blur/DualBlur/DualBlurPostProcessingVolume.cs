using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom Post-processing/Blur/DualBlur")]
public class DualBlurPostProcessingVolume : VolumeComponent, IPostProcessComponent
{
    //设置模糊偏移
    public FloatParameter PixelOffset = new ClampedFloatParameter(1, 0, 10);
    //模糊次数
    public IntParameter KawaseBlurTimes = new ClampedIntParameter(1, 0, 5);
    
    public IntParameter DualBlurTimes = new ClampedIntParameter(1, 0, 5);
    
    public IntParameter DownSample = new ClampedIntParameter(1, 1, 10);
    public bool IsActive() => active && DualBlurTimes.value > 0;
    public bool IsTileCompatible() => false;
}
