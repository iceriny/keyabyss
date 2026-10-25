using Godot;
using System;
using System.Collections.Generic;

/// <summary>Synchronous visual geometry; the caller owns RNG seeding and mesh publication.</summary>
public partial class LightningGeometry : RefCounted
{
    private readonly Vector2[] pathA = new Vector2[65];
    private readonly Vector2[] pathB = new Vector2[65];
    private readonly Vector2[] trunk = new Vector2[65];
    private readonly Vector2[] tips = new Vector2[7];
    private readonly List<Vector2> vertices = new();
    private readonly List<Vector2> uvs = new();
    private readonly List<Color> colors = new();
    private readonly List<int> indices = new();

    public Godot.Collections.Array Build(double reach, double burstRadius, int quality, RandomNumberGenerator rng)
    {
        if (!double.IsFinite(reach) || reach <= 0.0)
            throw new ArgumentOutOfRangeException(nameof(reach));
        if (!double.IsFinite(burstRadius) || burstRadius < 0.0)
            throw new ArgumentOutOfRangeException(nameof(burstRadius));
        if (quality < 0 || quality > 2)
            throw new ArgumentOutOfRangeException(nameof(quality));
        ArgumentNullException.ThrowIfNull(rng);

        vertices.Clear();
        uvs.Clear();
        colors.Clear();
        indices.Clear();
        if (burstRadius > 0.0)
        {
            double rotationOffset = rng.RandfRange(0.0f, (float)(Math.PI * 2.0));
            for (int index = 0; index < 7; index++)
            {
                double angle = rotationOffset + index * (Math.PI * 2.0) / 7.0;
                Vector2 tip = FromAngle((float)angle) * (float)burstRadius * rng.RandfRange(.78f, 1.0f);
                tips[index] = tip;
                AppendPath(Path(Vector2.Zero, tip, burstRadius * .16, rng), .8);
            }
            if (quality > 0)
                for (int index = 0; index < 7; index++)
                    AppendPath(Path(tips[index], tips[(index + 1) % 7], burstRadius * .1, rng), .28);
        }
        else
        {
            ReadOnlySpan<Vector2> main = Path(new Vector2((float)(-reach * .5), 0),
                new Vector2((float)(reach * .5), 0), reach * .085, rng);
            int trunkCount = main.Length;
            main.CopyTo(trunk);
            AppendPath(main, 1.0);
            int branches = quality == 0 ? 0
                : (int)Math.Ceiling(Math.Clamp((long)(reach / 95.0), 3L, 9L) * (quality == 1 ? .5 : 1.0));
            for (int index = 0; index < branches; index++)
            {
                int rootIndex = rng.RandiRange(2, trunkCount - 3);
                Vector2 origin = trunk[rootIndex];
                Vector2 direction = (trunk[rootIndex + 1] - trunk[rootIndex - 1]).Normalized();
                double side = rng.Randf() < .5 ? -1.0 : 1.0;
                double branchLength = Math.Min(reach * .3, 130.0);
                float rotation = (float)(side * (double)rng.RandfRange(.55f, 1.4f));
                Vector2 tip = origin + Rotated(direction, rotation)
                    * rng.RandfRange((float)(branchLength * .4), (float)branchLength);
                ReadOnlySpan<Vector2> branch = Path(origin, tip, (double)origin.DistanceTo(tip) * .18, rng);
                AppendPath(branch, rng.RandfRange(.18f, .42f));
                if (quality == 2 && index % 2 == 0)
                {
                    Vector2 fork = branch[(int)Math.Floor(branch.Length * .5)];
                    Vector2 end = fork + Rotated(direction, (float)(-side * .9)) * rng.RandfRange(15, 40);
                    AppendPath(Path(fork, end, 5.0, rng), .12);
                }
            }
        }

        // Each returned channel owns its data, independently of this shared workspace.
        var arrays = new Godot.Collections.Array();
        arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = vertices.ToArray();
        arrays[(int)Mesh.ArrayType.TexUV] = uvs.ToArray();
        arrays[(int)Mesh.ArrayType.Color] = colors.ToArray();
        arrays[(int)Mesh.ArrayType.Index] = indices.ToArray();
        return arrays;
    }

    private ReadOnlySpan<Vector2> Path(Vector2 start, Vector2 end, double displacement, RandomNumberGenerator rng)
    {
        Vector2[] points = pathA;
        Vector2[] divided = pathB;
        points[0] = start;
        points[1] = end;
        int count = 2;
        int levels = (int)Math.Clamp(Math.Ceiling(Math.Log((double)start.DistanceTo(end) / 9.0) / Math.Log(2.0)), 2.0, 6.0);
        for (int level = 0; level < levels; level++)
        {
            divided[0] = points[0];
            for (int index = 0; index < count - 1; index++)
            {
                Vector2 a = points[index];
                Vector2 b = points[index + 1];
                Vector2 normal = (b - a).Normalized().Orthogonal();
                Vector2 middle = a.Lerp(b, rng.RandfRange(.35f, .65f))
                    + normal * rng.RandfRange((float)-displacement, (float)displacement);
                divided[index * 2 + 1] = middle;
                divided[index * 2 + 2] = b;
            }
            count = count * 2 - 1;
            (points, divided) = (divided, points);
            displacement *= .48;
        }
        return points.AsSpan(0, count);
    }

    private void AppendPath(ReadOnlySpan<Vector2> points, double power)
    {
        for (int index = 0; index < points.Length - 1; index++)
        {
            Vector2 a = points[index];
            Vector2 b = points[index + 1];
            Vector2 axis = (b - a).Normalized();
            Vector2 side = axis.Orthogonal();
            double half = (double)a.DistanceTo(b) * .5;
            Vector2 center = (a + b) * .5f;
            double pad = power > .5 ? 13.0 : 7.0;
            Color color = LinearToSrgb(new Color((float)power, (float)((double)index / (points.Length - 1)), 0.0f, (float)(half / 64.0)));
            int first = vertices.Count;
            AppendCorner(new Vector2((float)(-half - pad), (float)-pad), center, axis, side, color);
            AppendCorner(new Vector2((float)(half + pad), (float)-pad), center, axis, side, color);
            AppendCorner(new Vector2((float)(half + pad), (float)pad), center, axis, side, color);
            AppendCorner(new Vector2((float)(-half - pad), (float)pad), center, axis, side, color);
            indices.Add(first); indices.Add(first + 1); indices.Add(first + 2);
            indices.Add(first); indices.Add(first + 2); indices.Add(first + 3);
        }
    }

    private void AppendCorner(Vector2 local, Vector2 center, Vector2 axis, Vector2 side, Color color)
    {
        vertices.Add(center + axis * local.X + side * local.Y);
        uvs.Add(local);
        colors.Add(color);
    }

    // Native Vector2 computes sine and cosine separately, rather than MathF.SinCos.
    private static Vector2 FromAngle(float angle) => new(MathF.Cos(angle), MathF.Sin(angle));

    private static Vector2 Rotated(Vector2 value, float angle)
    {
        float sine = MathF.Sin(angle);
        float cosine = MathF.Cos(angle);
        return new Vector2(value.X * cosine - value.Y * sine, value.X * sine + value.Y * cosine);
    }

    // Native Color uses float pow with double coefficients before storing float channels.
    private static float LinearChannel(float value) => value < .0031308f ? 12.92f * value
        : (float)((1.0 + .055) * MathF.Pow(value, 1.0f / 2.4f) - .055);

    private static Color LinearToSrgb(Color value) => new(LinearChannel(value.R), LinearChannel(value.G), LinearChannel(value.B), value.A);
}
