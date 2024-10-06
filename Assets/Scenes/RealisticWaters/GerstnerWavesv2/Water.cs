using UnityEngine;
using UnityEngine.Experimental.Rendering;
using Random = UnityEngine.Random;

[ExecuteAlways]
public class Water : MonoBehaviour
{
    public Gradient absorptionRamp;
    public Gradient scatterRamp;
    public Wave[] _waves;
    public int randomSeed = 3234;
    public BasicWaves _basicWaveSettings = new BasicWaves(1.5f, 45.0f, 5.0f);
    private Texture2D _rampTexture;
    private ComputeBuffer waveBuffer;
    private static readonly int AbsorptionScatteringRamp = Shader.PropertyToID("_AbsorptionScatteringRamp");

    private void OnEnable()
    {
        GenerateColorRamp();
        SetWaves();
    }
    
    [System.Serializable]
    public struct Wave
    {
        public float amplitude; // height of the wave in units(m)
        public float direction; // direction the wave travels in degrees from Z+
        public float wavelength; // distance between crest>crest
        public Vector2 origin; // Omi directional point of origin
        public float onmiDir; // Is omni?

        public Wave(float amp, float dir, float length, Vector2 org, bool omni)
        {
            amplitude = amp;
            direction = dir;
            wavelength = length;
            origin = org;
            onmiDir = omni ? 1 : 0;
        }
    }
    
    [System.Serializable]
    public class BasicWaves
    {
        public int numWaves = 6;
        public float amplitude;
        public float direction;
        public float wavelength;

        public BasicWaves(float amp, float dir, float len)
        {
            numWaves = 6;
            amplitude = amp;
            direction = dir;
            wavelength = len;
        }
    }

    public void SetWaves()
    {
        SetupWaves();
        Shader.SetGlobalInt("_WaveCount", _waves.Length);
        waveBuffer?.Dispose();
        waveBuffer = new ComputeBuffer(10, (sizeof(float) * 6));
        waveBuffer.SetData(_waves);
        Shader.SetGlobalBuffer("_WaveDataBuffer", waveBuffer);
    }
    
    private void SetupWaves()
    {
            //create basic waves based off basic wave settings
            var backupSeed = Random.state;
            Random.InitState(randomSeed);
            var basicWaves = _basicWaveSettings;
            var a = basicWaves.amplitude;
            var d = basicWaves.direction;
            var l = basicWaves.wavelength;
            var numWave = basicWaves.numWaves;
            _waves = new Wave[numWave];

            var r = 1f / numWave;

            for (var i = 0; i < numWave; i++)
            {
                var p = Mathf.Lerp(0.5f, 1.5f, i * r);
                var amp = a * p * Random.Range(0.8f, 1.2f);
                var dir = d + Random.Range(-90f, 90f);
                var len = l * p * Random.Range(0.6f, 1.4f);
                _waves[i] = new Wave(amp, dir, len, Vector2.zero, false);
                Random.InitState(randomSeed + i + 1);
            }
            Random.state = backupSeed;
    }

    private void GenerateColorRamp()
    {
        if(_rampTexture == null)
            _rampTexture = new Texture2D(128, 2, GraphicsFormat.R8G8B8A8_SRGB, TextureCreationFlags.None);
        _rampTexture.wrapMode = TextureWrapMode.Clamp;

        var cols = new Color[256];
        for (var i = 0; i < 128; i++)
        {
            cols[i] = absorptionRamp.Evaluate(i / 128f);
        }
        for (var i = 0; i < 128; i++)
        {
            cols[i + 128] = scatterRamp.Evaluate(i / 128f);
        }
        _rampTexture.SetPixels(cols);
        _rampTexture.Apply();
        Shader.SetGlobalTexture(AbsorptionScatteringRamp, _rampTexture);
    }
}
