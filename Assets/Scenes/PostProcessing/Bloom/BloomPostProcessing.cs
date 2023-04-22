using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BloomPostProcessing : ScriptableRendererFeature
{
    [Serializable]
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
        private static readonly int sourceTexId = Shader.PropertyToID("_SourceTex");

        private BlitSettings settings;

        private BloomPostProcessingVolume bloomPostProcessingVolume;
        
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier dest { get; set; }

        private string profilerTag;

        private readonly int buffer0 = Shader.PropertyToID("buffer0");
        private readonly int buffer1 = Shader.PropertyToID("buffer1");
        private const int BoxDownPrefilterPass = 0;
        private const int BoxDownPass = 1;
        private const int BoxUpPass = 2;
        private const int ApplyBloomPass = 3;
        private const int DebugBloomPass = 4;

        public BlitPass(BlitSettings settings, string tag)
        {
            this.renderPassEvent = settings.Event;
            this.settings = settings;
            this.material = CoreUtils.CreateEngineMaterial(settings.Shader);
            this.profilerTag = tag;
        }

        public void Setup(ScriptableRenderer renderer)
        {
            
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
            bloomPostProcessingVolume = stack.GetComponent<BloomPostProcessingVolume>();

            if (bloomPostProcessingVolume == null)
            {
                Debug.LogError("can't get volume");
                return;
            }
            
            if (!bloomPostProcessingVolume.IsActive())
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

        private void ProgressiveSampling(CommandBuffer cmd, int w, int h, int pass)
        {
            cmd.GetTemporaryRT(buffer1, w, h, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            cmd.SetGlobalTexture(mainTexId, buffer0);
            cmd.Blit(buffer0, buffer1, material, pass);
            cmd.ReleaseTemporaryRT(buffer0);
            cmd.GetTemporaryRT(buffer0, w, h, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            cmd.Blit(buffer1, buffer0);
            cmd.ReleaseTemporaryRT(buffer1);
        }

        private void Render(CommandBuffer cmd, RenderingData renderingData)
        {
            cmd.SetGlobalTexture(mainTexId, source);

            int iterations = bloomPostProcessingVolume.Iterations.value;
            float threshold = bloomPostProcessingVolume.Threshold.value;
            float softThreshold = bloomPostProcessingVolume.SoftThreshold.value;
            float knee = threshold * softThreshold;
            Vector4 filter;
            filter.x = threshold;
            filter.y = filter.x - knee;
            filter.z = 2f * knee;
            filter.w = 0.25f / (knee + 0.00001f);
            material.SetVector("_Filter", filter);
            material.SetFloat("_Intensity", bloomPostProcessingVolume.Intensity.value);
            
            int downSize = 2;

            int w = renderingData.cameraData.camera.scaledPixelWidth;
            int h = renderingData.cameraData.camera.scaledPixelHeight;

            int sourceW = w;
            int sourceH = h;

            w /= downSize;
            h /= downSize;
            
            cmd.GetTemporaryRT(buffer0, w, h, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            cmd.Blit(source, buffer0, material, BoxDownPrefilterPass);
            
            for (int i = 1; i < iterations; i++)
            {
                w /= downSize;
                h /= downSize;
                if (h <= 2)
                {
                    break;
                }
            
                ProgressiveSampling(cmd, w, h, BoxDownPass);
            }

            //由于没有持久的保存下采样时的RT所有没有在上采样Pass中使用Blend One One
            while (w < sourceW || h < sourceH)
            {
                w *= downSize;
                h *= downSize;

                ProgressiveSampling(cmd, w, h, BoxUpPass);
            }

            if (!bloomPostProcessingVolume.Debug.value)
            {
                cmd.SetGlobalTexture(sourceTexId, source);
                cmd.Blit(buffer0, dest, material, ApplyBloomPass);
            }
            else
            {
                cmd.Blit(buffer0, dest, material, DebugBloomPass);
            }
            cmd.ReleaseTemporaryRT(buffer0);
        }
    }
}
