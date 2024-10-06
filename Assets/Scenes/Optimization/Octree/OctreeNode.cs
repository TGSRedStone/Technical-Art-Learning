using System.Collections.Generic;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Scenes.Optimization.Octree
{
    public class OctreeNode
    {
        public List<OctreeObject> Objects = new List<OctreeObject>();

        private static int NextId;
        public readonly int ID;

        public Bounds Bounds;
        private Bounds[] childBounds = new Bounds[8];
        public OctreeNode[] ChildNodes;
        public bool IsLead => ChildNodes == null;

        private float minNodeSize;

        public OctreeNode(Bounds bounds, float minNodeSize)
        {
            ID = NextId++;
            Bounds = bounds;
            this.minNodeSize = minNodeSize;
            Vector3 newSize = bounds.size * 0.5f;
            Vector3 centerOffset = bounds.size * 0.25f;
            Vector3 parentCenter = bounds.center;

            for (int i = 0; i < 8; i++)
            {
                Vector3 childCenter = parentCenter;
                childCenter.x += centerOffset.x * ((i & 1) == 0 ? -1 : 1);
                childCenter.y += centerOffset.y * ((i & 2) == 0 ? -1 : 1);
                childCenter.z += centerOffset.z * ((i & 4) == 0 ? -1 : 1);
                childBounds[i] = new Bounds(childCenter, newSize);
            }
        }

        public void Divide(GameObject gameObject) => Divide(new OctreeObject(gameObject));

        private void Divide(OctreeObject octreeObject)
        {
            if (Bounds.size.x <= minNodeSize)
            {
                AddObject(octreeObject);
                return;
            }

            ChildNodes ??= new OctreeNode[8];
            bool intersectedChild = false;

            for (int i = 0; i < 8; i++)
            {
                ChildNodes[i] ??= new OctreeNode(childBounds[i], minNodeSize);

                if (octreeObject.Intersects(childBounds[i]))
                {
                    ChildNodes[i].Divide(octreeObject);
                    intersectedChild = true;
                }
            }

            if (!intersectedChild)
            {
                AddObject(octreeObject);
            }
        }

        private void AddObject(OctreeObject octreeObject)
        {
            Objects.Add(octreeObject);
        }
        
        public void DrawNode()
        {
            Gizmos.color = Color.green;
            Gizmos.DrawWireCube(Bounds.center, Bounds.size);

            foreach (var octreeObject in Objects)
            {
                if (octreeObject.Intersects(Bounds))
                {
                    Gizmos.color = Color.red;
                    Gizmos.DrawCube(Bounds.center, Bounds.size);
                }
            }
            
            if (ChildNodes != null)
            {
                foreach (var childNode in ChildNodes)
                {
                    if (childNode != null)
                    {
                        childNode.DrawNode();
                    }
                }
            }
        }
    }
}