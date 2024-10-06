using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public class ShadowSettings
{
    public float ShadowBias = 0.0f;
    public float ShadowNormalBias = 0.0f;
    public float ShadowStrength = 0.0f;
}

public class CustomShadowFeature : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.BeforeRenderingPrepasses;
    public FilterSettings FilterSettings;
    public Material Material;
    public ShadowSettings ShadowSettings = new ShadowSettings();

    private RenderTargetHandle _customShadowMap;

    CustomShadowCasterPass m_ScriptablePass;

    public override void Create()
    {
        if (Material == null) return;

        _customShadowMap.Init("_CustomShadowMap");

        var scriptablePass = new CustomShadowCasterPass(name, _customShadowMap, Event, FilterSettings, ShadowSettings);
        scriptablePass.overrideMaterial = Material;
        scriptablePass.overrideMaterialPassIndex = 0;

        m_ScriptablePass = scriptablePass;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }

    public class CustomShadowCasterPass : ScriptableRenderPass
    {
        public Material overrideMaterial { get; set; }
        public int overrideMaterialPassIndex { get; set; }

        private RenderTargetHandle _customShadowMap;
        private RenderQueueType _renderQueueType;
        private FilteringSettings _filteringSettings;
        private ShadowSettings _shadowSettings;
        private string _profilerTag;
        private ShaderTagId _shaderTagId = new ShaderTagId("CustomShadowCaster");

        public CustomShadowCasterPass(string profilerTag, RenderTargetHandle customShadowMap,
            RenderPassEvent renderPassEvent, FilterSettings filterSettings, ShadowSettings shadowSettings)
        {
            _customShadowMap = customShadowMap;
            _profilerTag = profilerTag;
            profilingSampler = new ProfilingSampler(nameof(CustomShadowCasterPass));

            this.renderPassEvent = renderPassEvent;
            _renderQueueType = filterSettings.renderQueueType;
            RenderQueueRange renderQueueRange = (filterSettings.renderQueueType == RenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;
            uint renderingLayerMask = (uint)1 << filterSettings.renderingLayerMask - 1;
            _filteringSettings = new FilteringSettings(renderQueueRange, filterSettings.layerMask, renderingLayerMask);
            _shadowSettings = shadowSettings;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            RenderTextureDescriptor descriptor = cameraTextureDescriptor;
            descriptor.width = 2048;
            descriptor.height = 2048;
            descriptor.depthBufferBits = 32;
            descriptor.colorFormat = RenderTextureFormat.ARGB32;

            cmd.GetTemporaryRT(_customShadowMap.id, descriptor, FilterMode.Point);
            ConfigureTarget(_customShadowMap.Identifier());
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(_profilerTag);
            cmd.SetGlobalFloat("_ShadowBias", _shadowSettings.ShadowBias);
            cmd.SetGlobalFloat("_ShadowNormalBias", _shadowSettings.ShadowNormalBias);
            cmd.SetGlobalFloat("_ShadowStrength", _shadowSettings.ShadowStrength);
            cmd.SetGlobalTexture("_CustomShadowMap", _customShadowMap.id);
            var projectionMatrix = GL.GetGPUProjectionMatrix(renderingData.cameraData.camera.projectionMatrix, false);
            cmd.SetGlobalMatrix("_WorldToShadow",
                projectionMatrix * renderingData.cameraData.camera.worldToCameraMatrix);
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
            cmd.ReleaseTemporaryRT(_customShadowMap.id);
        }
    }
}