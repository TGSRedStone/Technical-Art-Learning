using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;

public class NewBehaviourScript : MonoBehaviour
{
    [SerializeField]
    private Material _material;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.A))
        {
            _material.DOFloat(0.2f, "_LocalNormal", 2.0f);
        }
        if (Input.GetKeyDown(KeyCode.D))
        {
            _material.DOFloat(0.0f, "_LocalNormal", 2.0f);
        }
    }
}
