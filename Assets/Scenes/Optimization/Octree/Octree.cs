using UnityEngine;

namespace Scenes.Optimization.Octree
{
    public class Octree
    {
        public OctreeNode Root;
        public Bounds Bounds;

        public Octree(GameObject[] worldObjects, float minNodeSize)
        {
            CalculateBounds(worldObjects);
            CreateTree(worldObjects, minNodeSize);
        }

        private void CreateTree(GameObject[] worldObjects, float minNodeSize)
        {
            Root = new OctreeNode(Bounds, minNodeSize);

            foreach (var worldObject in worldObjects)
            {
                Root.Divide(worldObject);
            }
        }

        private void CalculateBounds(GameObject[] worldObjects)
        {
            foreach (var gameObject in worldObjects)
            {
                Bounds.Encapsulate(gameObject.GetComponent<Collider>().bounds);
            }

            Vector3 size = Vector3.one * Mathf.Max(Bounds.size.x, Bounds.size.y, Bounds.size.z) * 0.5f;
            Bounds.SetMinMax(Bounds.center - size, Bounds.center + size);
        }
    }
}

