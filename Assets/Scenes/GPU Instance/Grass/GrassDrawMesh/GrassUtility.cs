using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GrassUtility : MonoBehaviour
{
    private static Mesh _grassMesh;

    public static Mesh grassMesh
    {
        get
        {
            if (_grassMesh != null)
            {
                return _grassMesh;
            }

            _grassMesh = CreateGrassMesh();
            return _grassMesh;
        }
    }

    public static Mesh CreateGrassMesh()
    {
        var grassMesh = new Mesh { name = "GrassQuad" };
        float width = 1f;
        float height = 1f;
        float halfWidth = width / 2;
        grassMesh.SetVertices(new List<Vector3>
        {
            new Vector3(-halfWidth, 0.0f, 0.0f), new Vector3(-halfWidth, height, 0.0f),
            new Vector3(halfWidth, 0.0f, 0.0f), new Vector3(halfWidth, height, 0.0f)
        });
        grassMesh.SetUVs(0, new List<Vector2>
        {
            new Vector2(0, 0), new Vector2(0, 1), new Vector2(1, 0), new Vector2(1, 1)
        });
        grassMesh.SetIndices(new[] { 0, 1, 2, 2, 1, 3 }, MeshTopology.Triangles, 0, false);
        grassMesh.RecalculateNormals();
        grassMesh.UploadMeshData(true);
        return grassMesh;
    }

    //https://www.zhihu.com/question/31706710/answer/53236530
    public static Vector3 RandomPointInTriangle(Vector3 p1, Vector3 p2, Vector3 p3)
    {
        var x = Random.Range(0, 1f);
        var y = Random.Range(0, 1f);
        if (y > 1 - x)
        {
            var temp = y;
            y = 1 - x;
            x = 1 - temp;
        }
        var vx = p2 - p1;
        var vy = p3 - p1;
        return p1 + x * vx + y * vy;
    }

    public static float CalculateTriangleArea(Vector3 p1, Vector3 p2, Vector3 p3)
    {
        var vx = p2 - p1;
        var vy = p3 - p1;
        var dotvxy = Vector3.Dot(vx, vy);
        //S = |a| x |b| x sin0 = sqrt(|a|^2 + |b|^2 - (a·b)^2)
        var area = Mathf.Sqrt(vx.sqrMagnitude * vy.sqrMagnitude - dotvxy * dotvxy);
        return area;
    }

    public static Vector3 GetFaceNormal(Vector3 p1, Vector3 p2, Vector3 p3)
    {
        var vx = p2 - p1;
        var vy = p3 - p1;
        return Vector3.Cross(vx, vy);
    }
}