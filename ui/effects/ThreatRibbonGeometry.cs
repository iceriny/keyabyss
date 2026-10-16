using Godot;
using System;
using System.Collections.Generic;

/// <summary>Display-only geometry batch; no combat objects or per-point interop.</summary>
public partial class ThreatRibbonGeometry : RefCounted
{
    private const double MinSegment = 0.01;
    private readonly List<Vector2> points = new();
    private readonly List<Vector2> smooth = new();
    private readonly List<Vector2> trimmed = new();
    private readonly List<Vector2> vertices = new();
    private readonly List<Color> colors = new();
    private readonly List<Vector2> uvs = new();
    private readonly List<int> indices = new();
    private readonly List<double> distances = new();
    private readonly ArrayMesh mesh = new();

    // Offsets delimit normalized committed trails. Heads/radii/limits use pixels.
    public ArrayMesh Build(Vector2[] samples, int[] offsets, Vector2[] physicsHeads,
        Vector2[] renderHeads, double[] radii, double[] limits, Color[] tints,
        Vector2 size, bool halo)
    {
        int count = radii.Length;
        if (offsets.Length != count + 1 || physicsHeads.Length != count
            || renderHeads.Length != count || limits.Length != count || tints.Length != count
            || offsets[0] != 0 || offsets[count] != samples.Length)
            throw new ArgumentException("Invalid ribbon batch dimensions.");
        vertices.Clear(); colors.Clear(); uvs.Clear(); indices.Clear();
        for (int item = 0; item < count; item++)
        {
            if (offsets[item] > offsets[item + 1])
                throw new ArgumentException("Ribbon offsets must be ordered.");
            points.Clear();
            for (int i = offsets[item]; i < offsets[item + 1]; i++)
            {
                Vector2 point = samples[i] * size;
                if (points.Count == 0 || points[^1].DistanceTo(point) > MinSegment)
                    points.Add(point);
            }
            if (points.Count > 0 && points[^1].DistanceTo(physicsHeads[item]) <= MinSegment)
                points.RemoveAt(points.Count - 1);
            if (points.Count == 0 || points[^1].DistanceTo(renderHeads[item]) > MinSegment)
                points.Add(renderHeads[item]);
            else points[^1] = renderHeads[item];
            Trim(points, limits[item]);
            if (points.Count > 2)
            {
                Smooth();
                Trim(smooth, limits[item]);
            }
            else { smooth.Clear(); smooth.AddRange(points); }
            if (smooth.Count < 2) continue;
            Append(radii[item], tints[item], halo);
        }
        // Keep the resource identity. Only native upload happens after the batch.
        mesh.ClearSurfaces();
        if (vertices.Count == 0) return null;
        using var arrays = new Godot.Collections.Array();
        arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = vertices.ToArray();
        arrays[(int)Mesh.ArrayType.Color] = colors.ToArray();
        arrays[(int)Mesh.ArrayType.TexUV] = uvs.ToArray();
        arrays[(int)Mesh.ArrayType.Index] = indices.ToArray();
        mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
        return mesh;
    }

    private static Vector2 Lerp(Vector2 a, Vector2 b, double t) => a.Lerp(b, (float)t);

    private void Trim(List<Vector2> path, double remaining)
    {
        // Keep the original neighboring samples even when a tiny segment is skipped.
        trimmed.Clear();
        trimmed.Add(path[^1]);
        for (int i = path.Count - 2; i >= 0; i--)
        {
            double segment = path[i + 1].DistanceTo(path[i]);
            if (segment <= MinSegment) continue;
            if (segment > remaining)
            {
                trimmed.Add(Lerp(path[i + 1], path[i], remaining / segment));
                break;
            }
            trimmed.Add(path[i]);
            remaining -= segment;
            if (remaining <= MinSegment) break;
        }
        path.Clear();
        for (int i = trimmed.Count - 1; i >= 0; i--) path.Add(trimmed[i]);
    }

    private void Smooth()
    {
        smooth.Clear();
        int divisions = Math.Min(3, Math.Max(1, 47 / (points.Count - 1)));
        for (int i = 0; i < points.Count - 1; i++)
        {
            Vector2 a = points[i], b = points[i + 1];
            Vector2 before = i > 0 ? points[i - 1] : a + (a - b);
            Vector2 after = i + 2 < points.Count ? points[i + 2] : b + (b - a);
            // Centripetal knots depend on the segment, not on its subdivisions.
            double t1 = Math.Sqrt(before.DistanceTo(a));
            double t2 = t1 + Math.Sqrt(a.DistanceTo(b));
            double t3 = t2 + Math.Sqrt(b.DistanceTo(after));
            for (int sample = 0; sample < divisions; sample++)
            {
                double t = t1 + (t2 - t1) * ((double)sample / divisions);
                Vector2 a1 = Lerp(before, a, t / t1);
                Vector2 a2 = Lerp(a, b, (t - t1) / (t2 - t1));
                Vector2 a3 = Lerp(b, after, (t - t2) / (t3 - t2));
                Vector2 b1 = Lerp(a1, a2, t / t2);
                Vector2 b2 = Lerp(a2, a3, (t - t1) / (t3 - t1));
                smooth.Add(Lerp(b1, b2, (t - t1) / (t2 - t1)));
            }
        }
        smooth.Add(points[^1]);
    }

    private void Append(double radius, Color tint, bool halo)
    {
        distances.Clear();
        distances.Add(0.0);
        for (int i = 1; i < smooth.Count; i++)
            // Match the previous PackedFloat32Array's accumulated arc lengths.
            distances.Add((float)(distances[^1] + smooth[i - 1].DistanceTo(smooth[i])));
        int start = vertices.Count;
        int count = smooth.Count;
        // Preserve per-threat narrow strip then wide strip draw order.
        for (int layer = 0; layer < (halo ? 2 : 1); layer++)
            for (int i = 0; i < count * 2; i++)
            { vertices.Add(default); colors.Add(default); uvs.Add(default); }
        for (int i = 0; i < count; i++)
        {
            double progress = distances[i] / distances[^1];
            Vector2 before = smooth[Math.Max(0, i - 1)];
            Vector2 after = smooth[Math.Min(count - 1, i + 1)];
            Vector2 normal = (after - before).Normalized().Orthogonal();
            double taper = 0.08 + 0.92 * progress;
            double fade = Math.Pow(progress, 1.35);
            for (int layer = 0; layer < (halo ? 2 : 1); layer++)
            {
                int at = start + layer * count * 2 + i * 2;
                Vector2 side = normal * (float)(radius * (layer == 0 ? 2.6 : 7.0)) * (float)taper;
                vertices[at] = smooth[i] + side;
                vertices[at + 1] = smooth[i] - side;
                Color color = tint * (layer == 0 ? 1.75f : 1.3f);
                color.A = (float)((layer == 0 ? 0.7 : 0.13) * fade);
                colors[at] = colors[at + 1] = color;
                uvs[at] = new Vector2((float)progress, 0);
                uvs[at + 1] = new Vector2((float)progress, 1);
            }
        }
        for (int layer = 0; layer < (halo ? 2 : 1); layer++)
            for (int i = 0; i < count - 1; i++)
            {
                int at = start + layer * count * 2 + i * 2;
                indices.Add(at); indices.Add(at + 1); indices.Add(at + 2);
                indices.Add(at + 1); indices.Add(at + 3); indices.Add(at + 2);
            }
    }
}
