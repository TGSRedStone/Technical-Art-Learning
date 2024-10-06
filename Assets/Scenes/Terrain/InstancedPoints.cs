using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace Scenes.Terrain
{
    public class InstancedPoints
    {
        // public List<Vector3> GrassPosition = new List<Vector3>();
        // public List<Vector3> GrassNormal = new List<Vector3>();

        public void LoadGrassPoints()
        {
            string path = Application.streamingAssetsPath + "/grassPoints.csv";
            string[] datas = File.ReadAllLines(path);
            // GrassPosition.Clear();
            // GrassNormal.Clear();
            // GrassPosition = new List<Vector3>(datas.Length);
            // GrassNormal = new List<Vector3>(datas.Length);
            Debug.Log(datas.Length);
            for (int i = 0; i < datas.Length; i++)
            {
                string[] data = datas[i].Split(',');
                var point = new Vector3(-Convert.ToSingle(data[0]), Convert.ToSingle(data[1]), Convert.ToSingle(data[2])) / 2.5f;
                var normal = new Vector3(-Convert.ToSingle(data[3]), Convert.ToSingle(data[4]), Convert.ToSingle(data[5]));
                // GrassPosition.Add(point);
                // GrassNormal.Add(normal);
                GrassSpawner.Instance.AllGrassPosition.Add(new GrassPoint()
                {
                    Position = point,
                    Normal = normal
                });
            }
        }

        public void LoadTreePoints()
        {
            string path = Application.streamingAssetsPath + "/treePoints.csv";
            string[] datas = File.ReadAllLines(path);
            Debug.Log(datas.Length);
            for (int i = 0; i < datas.Length; i++)
            {
                string[] data = datas[i].Split(',');
                var point = new Vector3(-Convert.ToSingle(data[0]), Convert.ToSingle(data[1]), Convert.ToSingle(data[2])) / 2.5f;
                TreeSpawner.Instance.AllTreePosition.Add(new TreePoint()
                {
                    Position = point,
                });
            }
        }
    }
}