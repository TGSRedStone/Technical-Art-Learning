using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom Post-processing/Blur/TiltShiftBlur")]
public class TiltShiftBlurPostProcessingVolume : VolumeComponent, IPostProcessComponent
{
    //设置模糊偏移
    public FloatParameter BlurOffset = new ClampedFloatParameter(1, 0, 10);
    //模糊次数
    public IntParameter BlurTimes = new ClampedIntParameter(1, 0, 20);
    
    public IntParameter DownSample = new ClampedIntParameter(1, 1, 10);

    public FloatParameter CenterOffset = new ClampedFloatParameter(0, -1f, 1f);

    public FloatParameter AreaSize = new ClampedFloatParameter(0, 0f, 20f);
    
    public FloatParameter AreaSmooth = new ClampedFloatParameter(1, 0f, 20f);

    public bool IsActive() => active && BlurTimes.value > 0;
    public bool IsTileCompatible() => false;
}
