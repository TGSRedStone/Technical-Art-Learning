using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;
using Random = UnityEngine.Random;

[ExecuteInEditMode]
public class BubbleShield : MonoBehaviour
{
    public Material material;
    public LayerMask LayerMask;

    private RaycastHit raycastHit;
    private Vector3 point = Vector3.zero;

    private float[] points = {0, 0, 0, 0};

    void Update()
    {
        if (material == null) return;
        
        float t = points[3];

        Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
        if (Input.GetMouseButtonDown(0))
        {
            if (Physics.Raycast(ray, out raycastHit, 99, LayerMask.value))
            {
                point = raycastHit.point;
                // t = Random.Range(0.1f, 0.8f);
                t = 0.1f;
                if (t > 1)
                {
                    t = 0;
                }
            }
        }
        
        t += Time.deltaTime;
        
        points[0] = point.x;
        points[1] = point.y;
        points[2] = point.z;

        points[3] = t;

        material.SetFloatArray("_Points", points);
    }
}
