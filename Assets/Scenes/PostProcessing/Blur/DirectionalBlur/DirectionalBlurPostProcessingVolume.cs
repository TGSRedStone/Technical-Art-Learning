using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom Post-processing/Blur/DirectionalBlur")]
public class DirectionalBlurPostProcessingVolume : VolumeComponent, IPostProcessComponent
{
    //设置模糊偏移
    public FloatParameter BlurOffset = new ClampedFloatParameter(0, 0, 5);
    //模糊次数
    public IntParameter BlurTimes = new ClampedIntParameter(1, 0, 30);
    
    public FloatParameter BlurAngle = new ClampedFloatParameter(0, 0, 6);

    public IntParameter DownSample = new ClampedIntParameter(1, 1, 10);
    
    public bool IsActive() => active && BlurTimes.value > 0;
    public bool IsTileCompatible() => false;
}
