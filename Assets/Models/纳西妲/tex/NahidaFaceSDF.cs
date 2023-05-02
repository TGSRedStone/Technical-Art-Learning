using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

[ExecuteInEditMode]
public class NahidaFaceSDF : MonoBehaviour
{
    [SerializeField] private Transform headTransform;
    [SerializeField] private Transform headForward;
    [SerializeField] private Transform headRight;
    [SerializeField] private Material[] materials;
    [SerializeField] private Mesh[] meshs;

    [SerializeField] private List<Material> isNoFaceMaterials;
    [SerializeField] private List<Material> isFaceMaterials;

    private void Awake()
    {
        foreach (var material in isNoFaceMaterials)
        {
            material.DisableKeyword("_IsFace");
        }

        foreach (var material in isFaceMaterials)
        {
            material.EnableKeyword("_IsFace");
        }
        
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
