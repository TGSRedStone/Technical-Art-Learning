using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom Post-processing/Blur/GrainyBlur")]
public class GrainyBlurPostProcessingVolume : VolumeComponent, IPostProcessComponent
{
    //设置模糊偏移
    public FloatParameter BlurOffset = new ClampedFloatParameter(1, 0, 10);
    //模糊次数
    public IntParameter BlurTimes = new ClampedIntParameter(1, 0, 20);
    
    public IntParameter DownSample = new ClampedIntParameter(1, 1, 10);
    
    public bool IsActive() => active && BlurTimes.value > 0;
    public bool IsTileCompatible() => false;
}
