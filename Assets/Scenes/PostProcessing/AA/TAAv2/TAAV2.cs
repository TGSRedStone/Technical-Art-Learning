using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Scenes.PostProcessing.AA.TAAv2
{
    public class TAAV2 : VolumeComponent, IPostProcessComponent
    {
        public MotionBlurQualityParameter Quality = new MotionBlurQualityParameter(MotionBlurQuality.Low);

        public ClampedFloatParameter Spread = new ClampedFloatParameter(1.0f, 0f, 1.0f);

        public ClampedFloatParameter Feedback = new ClampedFloatParameter(0.0f, 0.0f, 1.0f);

        public bool IsActive() => Feedback.value > 0.0f && Feedback.overrideState == true;

        public bool IsTileCompatible() => false;
    }
}