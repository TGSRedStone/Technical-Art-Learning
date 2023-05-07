using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutLineRenderFeature : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;//和官方的一样用来表示什么时候插入Pass，默认在渲染完不透明物体后
    public FilterSettings filterSettings;//上面的一些自定义过滤设置
    public Material material;//我想用的新的渲染指定物体的材质
    public int[] passes;//我想指定的几个Pass的Index
    //下面三个是和Unity一样的深度设置
    public bool overrideDepthState = false;
    public CompareFunction depthCompareFunction = CompareFunction.LessEqual;
    public bool enableWrite = true;

    List<OutLineRenderPass> m_ScriptablePasses = new List<OutLineRenderPass>(2);

    /// <summary>
    /// 最重要的方法，用来生成RenderPass
    /// </summary>
    public override void Create()
    {
        if(passes == null) return;
        m_ScriptablePasses.Clear();
        //根据Shader的Pass数生成多个RenderPass
        for (int i = 0; i < passes.Length; i++)
        {
            var scriptablePass = new OutLineRenderPass(name, Event, filterSettings);
            scriptablePass.overrideMaterial = material;
            scriptablePass.overrideMaterialPassIndex = passes[i];

            if (overrideDepthState)
                scriptablePass.SetDepthState(enableWrite, depthCompareFunction);

            m_ScriptablePasses.Add(scriptablePass);
        }
    }
    //添加Pass到渲染队列
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(passes == null) return;
        foreach (var pass in m_ScriptablePasses)
        {
            renderer.EnqueuePass(pass);
        }
    }
    
    public class OutLineRenderPass : ScriptableRenderPass
    {
        //for debugger
        private string m_ProfilerTag;
        private ProfilingSampler m_ProfilingSampler;
        private RenderStateBlock m_RenderStateBlock;

        private RenderQueueType m_renderQueueType;
        private FilteringSettings m_FilteringSettings;

        public Material overrideMaterial { get; set; }
        public int overrideMaterialPassIndex { get; set; }

        private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>()
        {
            new ShaderTagId("SRPDefaultUnlit"),
            new ShaderTagId("UniversalForward"),
            new ShaderTagId("UniversalForwardOnly"),
            new ShaderTagId("LightweightForward")
        };
        //Pass的构造方法，参数都由Feature传入
        public OutLineRenderPass(string profilerTag ,RenderPassEvent renderPassEvent,FilterSettings filterSettings)
        {
            base.profilingSampler = new ProfilingSampler(nameof(OutLineRenderPass));
            m_ProfilerTag = profilerTag;
            m_ProfilingSampler = new ProfilingSampler(profilerTag);

            this.renderPassEvent = renderPassEvent;
            m_renderQueueType = filterSettings.renderQueueType;
            RenderQueueRange renderQueueRange = (filterSettings.renderQueueType == RenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;
            uint renderingLayerMask = (uint)1 << filterSettings.renderingLayerMask - 1;
            m_FilteringSettings = new FilteringSettings(renderQueueRange, filterSettings.layerMask, renderingLayerMask);

            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        }

        public void SetDepthState(bool writeEnabled, CompareFunction function = CompareFunction.Less)
        {
            m_RenderStateBlock.mask |= RenderStateMask.Depth;
            m_RenderStateBlock.depthState = new DepthState(writeEnabled, function);
        }

        /// <summary>
        /// 最重要的方法，用来定义CommandBuffer并执行
        /// </summary>
        /// <param name="context"></param>
        /// <param name="renderingData"></param>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            SortingCriteria sortingCriteria = (m_renderQueueType == RenderQueueType.Transparent)
                ? SortingCriteria.CommonTransparent
                : renderingData.cameraData.defaultOpaqueSortFlags;

            var drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);
            drawingSettings.overrideMaterial = overrideMaterial;
            drawingSettings.overrideMaterialPassIndex = overrideMaterialPassIndex;
            //这里不需要所以没有直接写CommandBuffer，在下面Feature的AddRenderPasses加入了渲染队列，底层还是CB
            context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);
        }
    }
}


