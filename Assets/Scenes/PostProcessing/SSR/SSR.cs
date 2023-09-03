using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SSR : ScriptableRendererFeature
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
        
        int SourID = Shader.PropertyToID("_SourceTex");

        private string profilerTag;

        public BlitPass(BlitSettings settings, string tag)
        {
            this.renderPassEvent = settings.Event;
            this.material = CoreUtils.CreateEngineMaterial(settings.Shader);
            this.profilerTag = tag;
        }

        public void Setup(ScriptableRenderer renderer)
        {
            ConfigureInput(ScriptableRenderPassInput.Normal);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            Matrix4x4 view = renderingData.cameraData.GetViewMatrix();
            Matrix4x4 proj = renderingData.cameraData.GetProjectionMatrix();
            view.SetColumn(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
            Matrix4x4 vp = proj * view;

            var near = renderingData.cameraData.camera.nearClipPlane;

            Matrix4x4 invView = vp.inverse;
            Vector4 nearTopLeftPoint = invView.MultiplyPoint(new Vector4(-1.0f, 1.0f, -1.0f, 1.0f));
            Vector4 nearTopRightPoint = invView.MultiplyPoint(new Vector4(1.0f, 1.0f, -1.0f, 1.0f));
            Vector4 nearBottomLeftPoint = invView.MultiplyPoint(new Vector4(-1.0f, -1.0f, -1.0f, 1.0f));

            Vector4 nearXVector = nearTopRightPoint - nearTopLeftPoint;
            Vector4 nearYVector = nearBottomLeftPoint - nearTopLeftPoint;

            material.SetVector("_NearTopLeftPoint", nearTopLeftPoint);
            material.SetVector("_NearXVector", nearXVector);
            material.SetVector("_NearYVector", nearYVector);

            ConfigureTarget(renderingData.cameraData.renderer.cameraColorTarget);
            ConfigureClear(ClearFlag.None, Color.white);
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
            cmd.SetGlobalTexture("_SourceTex", source);

            Render(cmd, renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void Render(CommandBuffer cmd, RenderingData renderingData)
        {
            RenderTextureDescriptor opaqueDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDescriptor.depthBufferBits = 0;
            cmd.GetTemporaryRT(SourID, opaqueDescriptor);
            cmd.CopyTexture(source, SourID);
            cmd.Blit(source, dest, material);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(SourID);
        }
    }
}
