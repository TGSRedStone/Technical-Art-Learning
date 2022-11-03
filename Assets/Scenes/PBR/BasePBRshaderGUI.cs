using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class BasePBRshaderGUI : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        base.OnGUI(materialEditor, properties);
        Material targetMat = materialEditor.target as Material;
 
        Texture normal = targetMat.GetTexture("_NormalTex");
        Texture metallic = targetMat.GetTexture("_MetallicTex");
        Texture roughness = targetMat.GetTexture("_RoughnessTex");
        
        if (normal != null)
            targetMat.EnableKeyword("_NORMAL_SETUP");
        else
            targetMat.DisableKeyword("_NORMAL_SETUP");
        
        if (metallic != null)
            targetMat.EnableKeyword("_METALLIC_SETUP");
        else
            targetMat.DisableKeyword("_METALLIC_SETUP");
        
        if (roughness != null)
            targetMat.EnableKeyword("_ROUGHNESS_SETUP");
        else
            targetMat.DisableKeyword("_ROUGHNESS_SETUP");
    }
}
