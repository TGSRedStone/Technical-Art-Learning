using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateAroundPoint : MonoBehaviour
{
    public Transform AroundPoint;
    public float speed = 10;

    private void Update()
    {
        transform.RotateAround(AroundPoint.position, Vector3.up, speed * Time.deltaTime);
    }
}
