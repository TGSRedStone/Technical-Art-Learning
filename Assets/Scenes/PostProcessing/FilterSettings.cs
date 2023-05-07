using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;

[Serializable]
public class FilterSettings
{
    public RenderQueueType renderQueueType;//透明还是不透明，Unity定义的enum
    public LayerMask layerMask;//渲染目标的Layer
    [Range(1, 32)] public int renderingLayerMask;//我想要指定的RenderingLayerMask

    public FilterSettings()
    {
        renderQueueType = RenderQueueType.Opaque;//默认不透明
        layerMask = -1;//默认渲染所有层
        renderingLayerMask = 32;//默认渲染32
    }
}
