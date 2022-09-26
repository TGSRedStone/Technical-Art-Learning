using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TiltShiftBlurPostProcessing : ScriptableRendererFeature
{
    [System.Serializable]
    public class BlitSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        public Shader Shader = null;
    }

    public BlitSettings Settings = new BlitSettings();
    private BlitPass blitPass;
    
    public override void Create()
    {
        if (Settings.Shader == null)
        {
            Debug.LogError("shader not exist");
            return;
        }
        blitPass = new BlitPass(Settings, name);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        blitPass.Setup(renderer);
        renderer.EnqueuePass(blitPass);
    }

    private class BlitPass : ScriptableRenderPass
    {
        private Material material = null;
        private static readonly int mainTexId = Shader.PropertyToID("_MainTex");

        private BlitSettings settings;

        private TiltShiftBlurPostProcessingVolume tiltShiftBlurPostProcessingVolume;
        
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier dest { get; set; }

        private Vector4 m_goldenRot = new Vector4();

        private string profilerTag;

        private readonly int buffer0 = Shader.PropertyToID("buffer0");
        private readonly int goldenRot = Shader.PropertyToID("_GoldenRot");
        private readonly int Params = Shader.PropertyToID("_Params");
        private readonly int gradient = Shader.PropertyToID("_Gradient");

        public BlitPass(BlitSettings settings, string tag)
        {
            this.renderPassEvent = settings.Event;
            this.settings = settings;
            this.material = CoreUtils.CreateEngineMaterial(settings.Shader);
            this.profilerTag = tag;
        }

        public void Setup(ScriptableRenderer renderer)
        {
            float c = Mathf.Cos(2.39996323f);
            float s = Mathf.Sin(2.39996323f);
            m_goldenRot.Set(c, s, -s, c);
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (material == null)
            {
                Debug.LogError("material not created");
                return;
            }

            if (!renderingData.cameraData.postProcessEnabled)
            {
                return;
            }

            var stack = VolumeManager.instance.stack;
            tiltShiftBlurPostProcessingVolume = stack.GetComponent<TiltShiftBlurPostProcessingVolume>();

            if (tiltShiftBlurPostProcessingVolume == null)
            {
                Debug.LogError("can't get volume");
                return;
            }
            
            if (!tiltShiftBlurPostProcessingVolume.IsActive())
            {
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            var renderer = renderingData.cameraData.renderer;
            source = renderer.cameraColorTarget;
            dest = renderer.cameraColorTarget;
            
            Render(cmd, renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void Render(CommandBuffer cmd, RenderingData renderingData)
        {
            cmd.SetGlobalTexture(mainTexId, source);
            
            int w = renderingData.cameraData.camera.scaledPixelWidth;
            int h = renderingData.cameraData.camera.scaledPixelHeight;
            
            int rtW = w / tiltShiftBlurPostProcessingVolume.DownSample.value;
            int rtH = h / tiltShiftBlurPostProcessingVolume.DownSample.value;
            
            cmd.GetTemporaryRT(buffer0, rtW,rtH,0, FilterMode.Bilinear);
            cmd.Blit(source,buffer0);
            
            cmd.SetGlobalVector(Params, new Vector4(tiltShiftBlurPostProcessingVolume.BlurTimes.value, tiltShiftBlurPostProcessingVolume.BlurOffset.value, 1f / w, 1f / h));
            cmd.SetGlobalVector(goldenRot, m_goldenRot);
            cmd.SetGlobalVector(gradient, new Vector3(tiltShiftBlurPostProcessingVolume.CenterOffset.value, tiltShiftBlurPostProcessingVolume.AreaSize.value, tiltShiftBlurPostProcessingVolume.AreaSmooth.value));

            cmd.Blit(buffer0, dest, material, 0);
            cmd.ReleaseTemporaryRT(buffer0);
        }
    }
}
