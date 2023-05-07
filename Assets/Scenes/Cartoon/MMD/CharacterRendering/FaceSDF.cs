using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

[ExecuteInEditMode]
public class FaceSDF : MonoBehaviour
{
    [SerializeField] private Transform headTransform;
    [SerializeField] private Transform headForward;
    [SerializeField] private Transform headRight;
    [SerializeField] private Material[] materials;

    private void Update()
    {
        Vector3 forwardVector = (headForward.position - headTransform.position).normalized;
        Vector3 rightVector = (headRight.position - headTransform.position).normalized;

        Vector4 forwardVector4 = new Vector4(forwardVector.x, forwardVector.y, forwardVector.z);
        Vector4 rightVector4 = new Vector4(rightVector.x, rightVector.y, rightVector.z);

        foreach (var material in materials)
        {
            material.SetVector("_ForwardVector", forwardVector4);
            material.SetVector("_RightVector", rightVector4);
        }
    }
}
