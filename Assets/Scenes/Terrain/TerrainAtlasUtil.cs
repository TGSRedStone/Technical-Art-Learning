using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class TerrainAtlasUtil : MonoBehaviour
{
    public List<Texture2D> Albedos;
    private Texture2D albedoAtlas;

    private int textureSqrCount = 2;
    private int textureSize = 2048;
    
    [ContextMenu("CreateTextureAtlas")]
    public void CreateTextureAtlas()
    {
        albedoAtlas = new Texture2D(textureSqrCount * textureSize, textureSqrCount * textureSize, TextureFormat.RGBA32, true);

        for (int i = 0; i < textureSqrCount; i++)
        {
            for (int j = 0; j < textureSqrCount; j++)
            {
                int index = i * textureSqrCount + j;
                
                albedoAtlas.SetPixels(j * textureSize, i * textureSize, textureSize, textureSize, Albedos[i + j].GetPixels());
            }
        }

        albedoAtlas.Apply();
        File.WriteAllBytes(Application.dataPath + "/Scenes/Terrain/albedoAtlas.png", albedoAtlas.EncodeToPNG());
        DestroyImmediate(albedoAtlas);
    }
}
