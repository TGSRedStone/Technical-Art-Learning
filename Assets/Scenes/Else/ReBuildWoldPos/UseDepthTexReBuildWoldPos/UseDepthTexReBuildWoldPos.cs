using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class UseDepthTexReBuildWoldPos : ScriptableRendererFeature
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

        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier dest { get; set; }

        private string profilerTag;

        public BlitPass(BlitSettings settings, string tag)
        {
            this.renderPassEvent = settings.Event;
            this.material = CoreUtils.CreateEngineMaterial(settings.Shader);
            this.profilerTag = tag;
        }

        public void Setup(ScriptableRenderer renderer)
        {

        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            Matrix4x4 view = renderingData.cameraData.GetViewMatrix();
            Matrix4x4 proj = GL.GetGPUProjectionMatrix(renderingData.cameraData.GetProjectionMatrix(), renderingData.cameraData.IsCameraProjectionMatrixFlipped());
            Matrix4x4 vp = proj * view;
            material.SetMatrix("_MATRIX_I_VP", vp.inverse);
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
            cmd.Blit(source, dest, material);
        }
    }
}
