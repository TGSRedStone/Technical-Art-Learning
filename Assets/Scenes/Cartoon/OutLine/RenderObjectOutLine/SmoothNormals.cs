using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class SmoothNormals : MonoBehaviour
{
    [SerializeField] private Mesh[] meshs;

    private void Awake()
    {
        foreach (var mesh in meshs)
        {
            IEnumerable<IEnumerable<KeyValuePair<Vector3, int>>> groups = mesh.vertices
                .Select((vertex, index) => new KeyValuePair<Vector3, int>(vertex, index)).GroupBy(pair => pair.Key);

            Vector3[] normals = mesh.normals;
            Vector4[] smoothNormals = normals.Select((normal, index) => new Vector4(normal.x, normal.y, normal.z)).ToArray();

            foreach (var group in groups)
            {
                if (group.Count() == 1)
                {
                    continue;
                }

                Vector3 smoothNormal = Vector3.zero;

                foreach (var pair in group)
                {
                    smoothNormal += normals[pair.Value];
                }
                smoothNormal.Normalize();

                foreach (var pair in group)
                {
                    smoothNormals[pair.Value] = new Vector4(smoothNormal.x, smoothNormal.y, smoothNormal.z);
                }
            }

            mesh.tangents = smoothNormals;
        }
    }
}
