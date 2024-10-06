using UnityEngine;

namespace Scenes.PostProcessing.AA.TAAv2
{
    internal sealed class TAAData
    {
        internal Vector2 SampleOffset;
        internal Matrix4x4 Project;
        internal Matrix4x4 PrevProject;
        internal Matrix4x4 PrevView;

        public TAAData()
        {
            this.SampleOffset = Vector2.zero;
            this.Project = Matrix4x4.identity;
            this.PrevProject = Matrix4x4.identity;
            this.PrevView = Matrix4x4.identity;
        }
    }
}