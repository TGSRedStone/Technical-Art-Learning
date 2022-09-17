using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class Decolorize : MonoBehaviour
{
    public ComputeShader ComputeShader;
    public Texture2D inputTex;
    public RawImage image;
    void Start()
    {
        RenderTexture t = new RenderTexture(inputTex.width, inputTex.height, 24);
        t.enableRandomWrite = true;
        t.Create();
        image.texture = t;
        int kernel = ComputeShader.FindKernel("CSMain");
        ComputeShader.SetTexture(kernel, "InputTex", inputTex);
        ComputeShader.SetTexture(kernel, "Result", t);
        ComputeShader.Dispatch(kernel, inputTex.width / 8, inputTex.height / 8, 1);
    }
}
