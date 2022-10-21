using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class LocalToWorld : MonoBehaviour
{
    public Transform DirectionalLight;
    public Material SkyBoxMaterial;
    private Matrix4x4 LtoW_Matrix = Matrix4x4.identity;
    private static readonly int LtoW = Shader.PropertyToID("_LtoW");
    
    [Range(1, 64)]
    public int SampleCount = 16;
    public float MaxRayLength = 400;
    
    [ColorUsage(false, true, 0, 10, 0, 10)]
    public Color IncomingLight = new Color(4, 4, 4, 4);
    [Range(0, 10.0f)]
    public float MieScatterCoef = 1;
    [Range(0, 10.0f)]
    public float MieExtinctionCoef = 1;
    [Range(0.0f, 0.999f)]
    public float MieG = 0.76f;

    public float AtmosphereHeight = 80000.0f;
    public float PlanetRadius = 6371000.0f;
    public Vector4 DensityScale = new Vector4(7994.0f, 1200.0f, 0, 0);
    public Vector4 MieSct = new Vector4(2.0f, 2.0f, 2.0f, 0.0f) * 0.00001f;

    private void Update()
    {
        LtoW_Matrix = DirectionalLight.localToWorldMatrix;
        SkyBoxMaterial.SetMatrix(LtoW, LtoW_Matrix);
        
        SkyBoxMaterial.SetFloat("_AtmosphereHeight", AtmosphereHeight);
        SkyBoxMaterial.SetFloat("_PlanetRadius", PlanetRadius);
        SkyBoxMaterial.SetVector("_DensityScaleHeight", DensityScale);

        SkyBoxMaterial.SetVector("_ScatteringM", MieSct * MieScatterCoef);
        SkyBoxMaterial.SetVector("_ExtinctionM", MieSct * MieExtinctionCoef);
        
        SkyBoxMaterial.SetColor("_IncomingLight", IncomingLight);
        SkyBoxMaterial.SetFloat("_MieG", MieG);
        
    }
}
