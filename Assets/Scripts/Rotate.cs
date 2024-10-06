using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Rotate : MonoBehaviour
{
    void FixedUpdate()
    {
        transform.Rotate(new Vector3(0, 10 * Time.deltaTime, 0), Space.Self);
    }

    private List<Transform> transforms;
    private MeshRenderer meshRenderer;
    private int materialCount = 0;

    private void a()
    {
        foreach (var transform in transforms)
        {
            meshRenderer = transform.GetComponent<MeshRenderer>();
            foreach (var material in meshRenderer.materials)
            {
                Debug.Log(material.name);
                materialCount++;
            }
        }
    }
}