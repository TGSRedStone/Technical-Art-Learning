using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class CreateShadowMapTexture : MonoBehaviour
{
    public ShadowResolution shadowQuality = ShadowResolution.Low;
    public ShadowType shadowType = ShadowType.HardShadow;
    private ShadowResolution currentShadowQuality;
    [Range(-0.3f, 0.3f)]
    public float Bias = 0;
    public Camera LightCam;
    private RenderTexture LightDepthTexture;
    public Shader DepthTextureShader;
    private static readonly int Bias1 = Shader.PropertyToID("_Bias");
    private static readonly int ShadowStrength = Shader.PropertyToID("_ShadowStrength");
    private static readonly int ShadowMapTexture = Shader.PropertyToID("_ShadowMapTexture");
    private static readonly int WorldToShadow = Shader.PropertyToID("_WorldToShadow");

    public enum ShadowResolution
    {
        Low = 1,
        Middle = 2,
        High = 4, 
        VeryHigh = 8,
    }
    
    public enum ShadowType
    {
        HardShadow,
        PCF,
    }
    
    private void InitDepthTexture(int resolution)
    {
        if (LightDepthTexture != null)
        {
            RenderTexture.ReleaseTemporary(LightDepthTexture);
        }
        LightDepthTexture = RenderTexture.GetTemporary(512 * resolution, 512 * resolution, 24, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        LightDepthTexture.filterMode = FilterMode.Point;
    }
    
    private void UpdateRenderTexture()
    {
        if (LightDepthTexture && currentShadowQuality != shadowQuality)
        {
            LightDepthTexture.Release();
            InitDepthTexture((int) shadowQuality);
            LightCam.targetTexture = LightDepthTexture;
            currentShadowQuality = shadowQuality;
        }

        if (!LightDepthTexture)
        {
            InitDepthTexture((int) shadowQuality);
            LightCam.targetTexture = LightDepthTexture;
        }
    }
    
    private void ResetCamera()
    {
        LightCam.backgroundColor = Color.white;
        LightCam.clearFlags = CameraClearFlags.SolidColor;
        LightCam.orthographic = true;
        LightCam.orthographicSize = 1.5f;
        LightCam.nearClipPlane = 1f;
        LightCam.farClipPlane = 5f;
        LightCam.enabled = false;
        LightCam.allowMSAA = false;
        LightCam.allowHDR = false;
        // LightCam.cullingMask = -1;
    }
    
    void Start()
    {
        currentShadowQuality = shadowQuality;
        if (!LightCam.targetTexture)
        {
            InitDepthTexture((int) currentShadowQuality);
            LightCam.targetTexture = LightDepthTexture;
        }
        ResetCamera();
    }
    
    void Update()
    {
        UpdateRenderTexture();
        Shader.SetGlobalFloat(Bias1, Bias);
        Shader.SetGlobalFloat(ShadowStrength, 0.5f);
        Shader.SetGlobalTexture(ShadowMapTexture, LightDepthTexture);
        if (shadowType == ShadowType.HardShadow)
        {
            Shader.EnableKeyword("_SHADOWTYPE_HARDSHADOW");
            Shader.DisableKeyword("_SHADOWTYPE_PCF");
        }
        else
        {
            Shader.EnableKeyword("_SHADOWTYPE_PCF");
            Shader.DisableKeyword("_SHADOWTYPE_HARDSHADOW");
        }
        
        LightCam.RenderWithShader(DepthTextureShader, "RenderType");

        var projectionMatrix = GL.GetGPUProjectionMatrix(LightCam.projectionMatrix, false);
        Shader.SetGlobalMatrix(WorldToShadow, projectionMatrix * LightCam.worldToCameraMatrix);
    }
}