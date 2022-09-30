using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class CreateRandomPNG : MonoBehaviour
{
    private Color RandomColor()
    {
        //随机颜色的HSV值,饱和度不变，只改变H值
        //H、S、V三个值的范围都是在0~1之间
        float h = Random.Range(0f, 1f);//随机值
        float s = 0.3f;//设置饱和度为定值
        Color color = Color.HSVToRGB(h, s, 1);
        return color;
    }
    void Start()
    {
        Texture2D png = new Texture2D(512, 512);
        for (int i = 0; i < 512; i++)
        {
            for (int j = 0; j < 512; j++)
            {
                png.SetPixel(i, j, RandomColor());
            }
        }
        png.Apply();
        
        File.WriteAllBytes(Application.streamingAssetsPath + ".png", png.EncodeToPNG());
    }


}
