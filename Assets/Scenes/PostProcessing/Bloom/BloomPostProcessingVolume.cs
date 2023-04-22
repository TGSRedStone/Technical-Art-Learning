using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom Post-processing/Bloom/CatLikeCodeBloom")]
public class BloomPostProcessingVolume : VolumeComponent, IPostProcessComponent
{
    public FloatParameter Intensity = new ClampedFloatParameter(1, 0, 10);
    public IntParameter Iterations = new ClampedIntParameter(1, 1, 10);
    public FloatParameter Threshold = new ClampedFloatParameter(1f, 0, 10);
    public FloatParameter SoftThreshold = new ClampedFloatParameter(0.5f, 0, 1);
    public BoolParameter Debug = new BoolParameter(false);
    public bool IsActive() => active && Iterations.value > 0;
    public bool IsTileCompatible() => false;
}
