using Godot;
using System;
using System.Collections.Generic;
using System.Buffers.Binary;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

/// <summary>Display-only geometry batch; no combat objects or per-point interop.</summary>
public partial class ThreatRibbonGeometry : RefCounted
{
    private readonly Geometry[] workers = { new(), new(), new(), new() };
    private readonly Geometry merged = new();
    private int workerLimit = Math.Clamp(System.Environment.ProcessorCount / 2, 1, 4);
    private readonly ParallelOptions parallelOptions = new();
    private readonly ArrayMesh mesh = new();
    private int vertexCapacity, indexCapacity, previousIndexCount;
    private byte[] attributes = Array.Empty<byte>();
    private byte[] indexBytes = Array.Empty<byte>();
    private int indexStride;

    public void SetWorkerLimit(int count)
    {
        if (count < 1 || count > workers.Length) throw new ArgumentOutOfRangeException(nameof(count));
        workerLimit = count;
    }

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
        for (int item = 0; item < count; item++)
        {
            if (offsets[item] > offsets[item + 1])
                throw new ArgumentException("Ribbon offsets must be ordered.");
        }
        // At least 64 ribbons per chunk; small batches avoid scheduling and merge cost.
        int jobs = Math.Clamp(count / 64, 1, workerLimit);
        Geometry result;
        if (jobs == 1)
        {
            result = workers[0];
            result.BuildRange(0, count, samples, offsets, physicsHeads, renderHeads, radii, limits, tints, size, halo);
        }
        else
        {
            // Workers touch only managed arrays and their own numeric workspace.
            // Join before native mesh calls; deterministic merge preserves transparent order.
            parallelOptions.MaxDegreeOfParallelism = jobs;
            Parallel.For(0, jobs, parallelOptions, job =>
                workers[job].BuildRange(count * job / jobs, count * (job + 1) / jobs,
                    samples, offsets, physicsHeads, renderHeads, radii, limits, tints, size, halo));
            result = merged;
            result.Clear();
            for (int job = 0; job < jobs; job++) result.AppendBatch(workers[job]);
        }
        if (result.vertices.Count == 0) return null;
        Upload(result);
        return mesh;
    }

    private void Upload(Geometry geometry)
    {
        var vertices = geometry.vertices;
        var colors = geometry.colors;
        var uvs = geometry.uvs;
        var indices = geometry.indices;
        if (vertices.Count > vertexCapacity || indices.Count > indexCapacity)
        {
            vertexCapacity = (int)System.Numerics.BitOperations.RoundUpToPowerOf2((uint)vertices.Count);
            indexCapacity = (int)System.Numerics.BitOperations.RoundUpToPowerOf2((uint)((indices.Count + 2) / 3)) * 3;
            mesh.ClearSurfaces();
            using var arrays = new Godot.Collections.Array();
            arrays.Resize((int)Mesh.ArrayType.Max);
            arrays[(int)Mesh.ArrayType.Vertex] = new Vector2[vertexCapacity];
            arrays[(int)Mesh.ArrayType.Color] = new Color[vertexCapacity];
            arrays[(int)Mesh.ArrayType.TexUV] = new Vector2[vertexCapacity];
            arrays[(int)Mesh.ArrayType.Index] = new int[indexCapacity];
            mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays,
                flags: Mesh.ArrayFormat.FlagUseDynamicUpdate);
            var format = (RenderingServer.ArrayFormat)mesh.SurfaceGetFormat(0);
            // Native interop boundary: uncompressed Vector2 + RGBA8 + Vector2 UV.
            if (RenderingServer.MeshSurfaceGetFormatVertexStride(format, vertexCapacity) != 8
                || RenderingServer.MeshSurfaceGetFormatAttributeStride(format, vertexCapacity) != 12
                || RenderingServer.MeshSurfaceGetFormatOffset(format, vertexCapacity, (int)Mesh.ArrayType.Color) != 0
                || RenderingServer.MeshSurfaceGetFormatOffset(format, vertexCapacity, (int)Mesh.ArrayType.TexUV) != 4)
                throw new InvalidOperationException("Unexpected ribbon surface layout.");
            indexStride = vertexCapacity <= 65536 ? 2 : 4;
            attributes = new byte[vertexCapacity * 12];
            indexBytes = new byte[indexCapacity * indexStride];
            previousIndexCount = 0;
        }
        Vector2 minimum = vertices[0], maximum = vertices[0];
        for (int i = 0; i < vertices.Count; i++)
        {
            minimum = minimum.Min(vertices[i]); maximum = maximum.Max(vertices[i]);
            Color c = colors[i];
            int at = i * 12;
            // Match ArrayMesh's original RGBA8 conversion, including truncation.
            attributes[at] = (byte)(Math.Clamp(c.R, 0f, 1f) * 255f);
            attributes[at + 1] = (byte)(Math.Clamp(c.G, 0f, 1f) * 255f);
            attributes[at + 2] = (byte)(Math.Clamp(c.B, 0f, 1f) * 255f);
            attributes[at + 3] = (byte)(Math.Clamp(c.A, 0f, 1f) * 255f);
            BinaryPrimitives.WriteSingleLittleEndian(attributes.AsSpan(at + 4), uvs[i].X);
            BinaryPrimitives.WriteSingleLittleEndian(attributes.AsSpan(at + 8), uvs[i].Y);
        }
        for (int i = 0; i < indices.Count; i++)
            if (indexStride == 2)
                BinaryPrimitives.WriteUInt16LittleEndian(indexBytes.AsSpan(i * 2), (ushort)indices[i]);
            else
                BinaryPrimitives.WriteInt32LittleEndian(indexBytes.AsSpan(i * 4), indices[i]);
        // Removed tails become degenerate triangles; they must never retain old indices.
        if (previousIndexCount > indices.Count)
            Array.Clear(indexBytes, indices.Count * indexStride, (previousIndexCount - indices.Count) * indexStride);
        mesh.CustomAabb = new Aabb(new Vector3(minimum.X, minimum.Y, 0),
            new Vector3(maximum.X - minimum.X, maximum.Y - minimum.Y, 1));
        mesh.SurfaceUpdateVertexRegion(0, 0, MemoryMarshal.AsBytes(CollectionsMarshal.AsSpan(vertices)));
        mesh.SurfaceUpdateAttributeRegion(0, 0, attributes.AsSpan(0, vertices.Count * 12));
        RenderingServer.MeshSurfaceUpdateIndexRegion(mesh.GetRid(), 0, 0,
            indexBytes.AsSpan(0, Math.Max(indices.Count, previousIndexCount) * indexStride));
        previousIndexCount = indices.Count;
    }

    private sealed class Geometry
    {
        private const double MinSegment = 0.01;
        private readonly List<Vector2> points = new();
        private readonly List<Vector2> smooth = new();
        private readonly List<Vector2> trimmed = new();
        internal readonly List<Vector2> vertices = new();
        internal readonly List<Color> colors = new();
        internal readonly List<Vector2> uvs = new();
        internal readonly List<int> indices = new();
        private readonly List<double> distances = new();

        internal void Clear()
        {
            vertices.Clear(); colors.Clear(); uvs.Clear(); indices.Clear();
        }

        internal void AppendBatch(Geometry batch)
        {
            int start = vertices.Count;
            vertices.AddRange(batch.vertices); colors.AddRange(batch.colors); uvs.AddRange(batch.uvs);
            foreach (int index in batch.indices) indices.Add(start + index);
        }

        internal void BuildRange(int first, int end, Vector2[] samples, int[] offsets,
            Vector2[] physicsHeads, Vector2[] renderHeads, double[] radii, double[] limits,
            Color[] tints, Vector2 size, bool halo)
        {
            Clear();
            for (int item = first; item < end; item++)
            {
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
                if (smooth.Count >= 2) Append(radii[item], tints[item], halo);
            }
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
                    float halfWidth = (float)(radius * (layer == 0 ? 2.6 : 7.0) * taper);
                    // Interpolate physical distance and width separately. Normalized UVs
                    // on a tapered quad bend the optical center at every triangle diagonal.
                    uvs[at] = new Vector2(halfWidth, -halfWidth);
                    uvs[at + 1] = new Vector2(halfWidth, halfWidth);
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
}
