using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using DG.Tweening;

public class PrintDotween : MonoBehaviour
{
    public Material Material;

    private bool isPlaying = false;
    private static readonly int CutY = Shader.PropertyToID("_CutY");

    private void Start()
    {
        Material.SetFloat(CutY, 1.8f);
        Material.DOFloat(-0.7f, CutY, 2f).SetLoops(-1, LoopType.Yoyo).SetEase(Ease.InQuad);
    }
}
