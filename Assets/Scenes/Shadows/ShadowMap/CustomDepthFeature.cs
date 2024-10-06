using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomDepthFeature : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.BeforeRenderingPrepasses;
    public FilterSettings FilterSettings;
    public Material Material;

    private RenderTargetHandle _customDepthTexture;

    CustomDepthPass m_ScriptablePass;

    public override void Create()
    {
        if (Material == null) return;

        _customDepthTexture.Init("_CustomDepthTexture");

        var scriptablePass = new CustomDepthPass(name, _customDepthTexture, Event, FilterSettings);
        scriptablePass.overrideMaterial = Material;
        scriptablePass.overrideMaterialPassIndex = 0;

        m_ScriptablePass = scriptablePass;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }

    public class CustomDepthPass : ScriptableRenderPass
    {
        public Material overrideMaterial { get; set; }
        public int overrideMaterialPassIndex { get; set; }

        private RenderTargetHandle _customDepthTexture;
        private RenderQueueType _renderQueueType;
        private FilteringSettings _filteringSettings;
        private string _profilerTag;
        private ShaderTagId _shaderTagId = new ShaderTagId("CustomDepthPass");

        public CustomDepthPass(string profilerTag, RenderTargetHandle customDepthTexture,
            RenderPassEvent renderPassEvent, FilterSettings filterSettings)
        {
            _customDepthTexture = customDepthTexture;
            _profilerTag = profilerTag;
            profilingSampler = new ProfilingSampler(nameof(CustomDepthPass));

            this.renderPassEvent = renderPassEvent;
            _renderQueueType = filterSettings.renderQueueType;
            RenderQueueRange renderQueueRange = (filterSettings.renderQueueType == RenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;
            uint renderingLayerMask = (uint)1 << filterSettings.renderingLayerMask - 1;
            _filteringSettings = new FilteringSettings(renderQueueRange, filterSettings.layerMask, renderingLayerMask);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            RenderTextureDescriptor descriptor = cameraTextureDescriptor;
            descriptor.width = 2048;
            descriptor.height = 2048;
            descriptor.depthBufferBits = 32;
            descriptor.colorFormat = RenderTextureFormat.ARGB32;

            cmd.GetTemporaryRT(_customDepthTexture.id, descriptor, FilterMode.Point);
            ConfigureTarget(_customDepthTexture.Identifier());
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(_profilerTag);
            cmd.SetGlobalTexture("_CustomDepthTexture", _customDepthTexture.id);
            var projectionMatrix = GL.GetGPUProjectionMatrix(renderingData.cameraData.camera.projectionMatrix, false);
            cmd.SetGlobalMatrix("_inverseVP", Matrix4x4.Inverse(projectionMatrix * renderingData.cameraData.camera.worldToCameraMatrix));
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            using (new ProfilingScope(cmd, profilingSampler))
            {
                SortingCriteria sortingCriteria = (_renderQueueType == RenderQueueType.Transparent)
                    ? SortingCriteria.CommonTransparent
                    : renderingData.cameraData.defaultOpaqueSortFlags;

                var drawingSettings = CreateDrawingSettings(_shaderTagId, ref renderingData, sortingCriteria);
                drawingSettings.overrideMaterial = overrideMaterial;
                drawingSettings.overrideMaterialPassIndex = overrideMaterialPassIndex;

                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref _filteringSettings);
            }

            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(_customDepthTexture.id);
        }
    }
}