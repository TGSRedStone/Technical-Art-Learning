using UnityEngine;

namespace DefaultNamespace
{
    public class SingletonMono<T> : MonoBehaviour where T : MonoBehaviour
    {
        private static T INSTANCE;

        public static T Instance
        {
            get { return INSTANCE; }
        }

        private void Awake()
        {
            INSTANCE = this as T;
            InitAwake();
        }

        protected virtual void InitAwake()
        {
        }
    }
}