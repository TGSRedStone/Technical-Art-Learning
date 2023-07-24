using Unity.Mathematics;
public readonly struct HashingSpaceSmallXXHash
{
    const uint primeA = 0b10011110001101110111100110110001;
    const uint primeB = 0b10000101111010111100101001110111;
    const uint primeC = 0b11000010101100101010111000111101;
    const uint primeD = 0b00100111110101001110101100101111;
    const uint primeE = 0b00010110010101100110011110110001;

    readonly uint accumulator;

    public HashingSpaceSmallXXHash (uint accumulator)
    {
        this.accumulator = accumulator;
    }

    public static implicit operator HashingSpaceSmallXXHash (uint accumulator) =>
        new HashingSpaceSmallXXHash(accumulator);

    public static HashingSpaceSmallXXHash Seed (int seed) => (uint)seed + primeE;

    static uint RotateLeft (uint data, int steps) =>
        (data << steps) | (data >> 32 - steps);

    public HashingSpaceSmallXXHash Eat (int data) =>
        RotateLeft(accumulator + (uint)data * primeC, 17) * primeD;

    public HashingSpaceSmallXXHash Eat (byte data) =>
        RotateLeft(accumulator + data * primeE, 11) * primeA;

    public static implicit operator uint (HashingSpaceSmallXXHash hash)
    {
        uint avalanche = hash.accumulator;
        avalanche ^= avalanche >> 15;
        avalanche *= primeB;
        avalanche ^= avalanche >> 13;
        avalanche *= primeC;
        avalanche ^= avalanche >> 16;
        return avalanche;
    }

    public static implicit operator HashingSpaceSmallXXHash4 (HashingSpaceSmallXXHash hash) =>
        new HashingSpaceSmallXXHash4(hash.accumulator);
}

public readonly struct HashingSpaceSmallXXHash4
{
    const uint primeB = 0b10000101111010111100101001110111;
    const uint primeC = 0b11000010101100101010111000111101;
    const uint primeD = 0b00100111110101001110101100101111;
    const uint primeE = 0b00010110010101100110011110110001;
        
    readonly uint4 accumulator;

    public HashingSpaceSmallXXHash4 (uint4 accumulator)
    {
        this.accumulator = accumulator;
    }

    public static HashingSpaceSmallXXHash4 Seed(int4 seed) => (uint4) seed + primeE;

    public HashingSpaceSmallXXHash4 Eat(int4 data) =>
        RotateLeft(accumulator + (uint4) data * primeC, 17) * primeD;
    
    static uint4 RotateLeft(uint4 data, int steps) => (data << steps) | (data >> 32 - steps);

    public static implicit operator HashingSpaceSmallXXHash4(uint4 accumulator) =>
        new HashingSpaceSmallXXHash4(accumulator);
    
    public static implicit operator uint4 (HashingSpaceSmallXXHash4 hash)
    {
        uint4 avalanche = hash.accumulator;
        avalanche ^= avalanche >> 15;
        avalanche *= primeB;
        avalanche ^= avalanche >> 13;
        avalanche *= primeC;
        avalanche ^= avalanche >> 16;
        return avalanche;
    }
}