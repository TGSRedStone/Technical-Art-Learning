using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TAACamera : MonoBehaviour
{
    private Camera camera;

    private void Start()
    {
        camera = GetComponent<Camera>();
        camera.ResetProjectionMatrix();
    }

    private void OnDisable()
    {
        camera.ResetProjectionMatrix();
    }
}
