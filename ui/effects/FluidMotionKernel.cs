using Godot;
using System;
using System.Collections.Generic;

// Scene-local motion only. Gameplay and Godot nodes remain on the main thread.
public partial class FluidMotionKernel : RefCounted
{
    private sealed class Motion
    {
        public Vector2 Previous, Point, Extent;
        public double PreviousAngle, FlowAngle, Angle, Glow, Gain, LastPlumeDensity;
        public Color Color;
        public int Flags;
        public readonly Vector2[] Points = new Vector2[10];
        public int Count;

        public void Reset()
        {
            Previous = Point;
            PreviousAngle = Angle;
            Points[0] = Point;
            Count = 1;
        }

        public void Append(Vector2 point)
        {
            if (Count == 0) { Points[Count++] = point; return; }
            if (Points[Count - 1].DistanceSquaredTo(point) < .01) return;
            Points[Count++] = point;
            if (Count > 2 && Deviation(Count - 2) < .5) RemovePoint(Count - 2);
            if (Count <= 9) return;
            int least = 1;
            for (int i = 2; i < Count - 1; i++)
                if (Deviation(i) < Deviation(least)) least = i;
            RemovePoint(least);
        }

        private void RemovePoint(int index)
        {
            System.Array.Copy(Points, index + 1, Points, index, Count - index - 1);
            Count--;
        }

        private float Deviation(int index)
        {
            Vector2 start = Points[index - 1], end = Points[index + 1];
            Vector2 n = end - start;
            float l2 = n.LengthSquared();
            Vector2 closest = start;
            if (l2 >= 1e-20f)
            {
                float d = n.Dot(Points[index] - start) / l2;
                closest = d <= 0 ? start : d >= 1 ? end : start + n * d;
            }
            return Points[index].DistanceTo(closest);
        }
    }

    private readonly List<Motion> motions = new();
    private readonly Stack<int> free = new();
    private readonly List<int> lightHandles = new();
    private readonly List<float> records = new(48 * 28);

    public void Prepare()
    {
        using var kernel = new FluidMotionKernel();
        int handle = kernel.Add(Vector2.Zero, 0);
        int[] handles = { handle };
        Vector2[] extents = { new Vector2(8, 8) };
        Color[] colors = { Colors.White };
        int[] flags = { 2 };
        kernel.Update(handles, new[] { Vector2.Zero }, extents, new double[] { 0, 1, 5 }, colors, flags, true);
        kernel.Update(handles, new[] { new Vector2(5, 3) }, extents, new double[] { .1, 1, 5 }, colors, flags, true);
        using var result = kernel.Consume(handles, 1.0 / 60.0, 48, true, System.Array.Empty<double>(), Colors.White, Colors.White);
        kernel.LightEnergies(handles);
        using var light = kernel.Light(0);
        kernel.Rebase(handles);
        kernel.Remove(handle);
    }

    public int Add(Vector2 point, double angle)
    {
        var motion = new Motion { Previous = point, Point = point, PreviousAngle = angle, FlowAngle = angle };
        if (free.Count == 0) { motions.Add(motion); return motions.Count - 1; }
        int handle = free.Pop();
        motions[handle] = motion;
        return handle;
    }

    public void Remove(int handle)
    {
        Get(handle);
        motions[handle] = null;
        free.Push(handle);
    }

    // Values: angle, glow, gain. Flags: bit 0 solid, bit 1 pointed.
    // Repeated handles are processed in input order (pointer gestures may turn several times).
    public bool Update(int[] handles, Vector2[] points, Vector2[] extents, double[] values, Color[] colors, int[] flags, bool pathsActive)
    {
        int count = handles.Length;
        if (points.Length != count || extents.Length != count || values.Length != count * 3 || colors.Length != count || flags.Length != count)
            throw new ArgumentException("Fluid motion batch lengths differ");
        bool orderDirty = false;
        for (int i = 0; i < count; i++)
        {
            Motion m = Get(handles[i]);
            orderDirty |= m.Glow != values[i * 3 + 1];
            if (pathsActive) m.Append(points[i]);
            m.Point = points[i]; m.Extent = extents[i]; m.Angle = values[i * 3];
            m.Glow = values[i * 3 + 1]; m.Gain = values[i * 3 + 2];
            m.Color = colors[i]; m.Flags = flags[i];
        }
        return orderDirty;
    }

    public void Rebase(int[] handles)
    {
        foreach (int handle in handles) Get(handle).Reset();
    }

    public double[] Glows()
    {
        double[] values = new double[motions.Count];
        for (int i = 0; i < motions.Count; i++) values[i] = motions[i]?.Glow ?? 0;
        return values;
    }

    // The caller preserves Godot's native equal-key sort, starting in insertion order.
    // Medium is empty or density_scale, temperature, dissipation, emission; color is already linear.
    public Godot.Collections.Array Consume(int[] ordered, double delta, int capacity, bool battle, double[] medium, Color mediumColor, Color fogColor)
    {
        if (delta <= 0 || !double.IsFinite(delta) || capacity < 0 || capacity > 48 || (medium.Length != 0 && medium.Length != 4))
            throw new ArgumentException("Invalid fluid motion consume parameters");
        records.Clear();
        int omitted = 0;
        foreach (int handle in ordered)
        {
            Motion m = Get(handle);
            double distance = 0;
            for (int i = 1; i < m.Count; i++) distance += m.Points[i - 1].DistanceTo(m.Points[i]);
            double speed = distance / delta;
            double difference = (m.Angle - m.PreviousAngle) % Math.Tau;
            double angular = ((2.0 * difference) % Math.Tau - difference) / delta;
            double radius = Math.Max(m.Extent.X, m.Extent.Y);
            bool wake = (m.Flags & 1) != 0 || speed > 1.0 || Math.Abs(angular) > .01;
            bool plume = battle && (m.Flags & 1) == 0 && speed > 12.0;
            int segments = Math.Max(1, m.Count - 1);
            for (int i = 0; i < segments; i++)
            {
                Vector2 start = m.Points[i], end = m.Points[Math.Min(i + 1, m.Count - 1)];
                Vector2 segment = end - start;
                if (segment.LengthSquared() > 0) m.FlowAngle = segment.Angle();
                if (records.Count / 28 >= capacity) { omitted += (wake ? 1 : 0) + (plume ? 1 : 0); continue; }
                Vector2 direction = segment.Normalized();
                Vector2 velocity = direction * (float)speed;
                double length = segment.Length();
                if (wake)
                    Pack(start, end, radius * 3.2, velocity, 0, 0, m.FlowAngle, Math.Clamp(angular, -4, 4),
                        fogColor, m.Gain * Exposure(length, distance, radius), radius, (m.Flags & 2) != 0 ? 2.4 : 0, 0, 0);
                if (plume)
                {
                    if (records.Count / 28 >= capacity) { omitted++; continue; }
                    double width = Math.Clamp(radius * .8, 18, 80);
                    double rearLength = radius * ((m.Flags & 2) != 0 ? 2.4 : 1.0);
                    Vector2 offset = direction * (float)rearLength * .35f;
                    Vector2 plumeStart = start - offset, plumeEnd = end - offset;
                    double exposure = Exposure(length, distance, width);
                    double density = Math.Min(speed / width * .65, 32.0) * exposure;
                    double heat = 0, dissipation = 0, emission = 0;
                    Color tint = m.Color.A == 0 ? fogColor : ToLinear(m.Color);
                    if (medium.Length != 0)
                    {
                        tint = mediumColor; density *= medium[0]; heat += density * medium[1];
                        dissipation = medium[2]; emission = medium[3];
                    }
                    m.LastPlumeDensity = density;
                    Pack(plumeStart, plumeEnd, width, velocity * .08f, density, heat, (plumeEnd - plumeStart).Angle(), 0,
                        tint, 3.0 * exposure, 0, 0, dissipation, emission);
                }
            }
            m.Reset();
        }
        return new Godot.Collections.Array { records.ToArray(), omitted };
    }

    public double[] LightEnergies(int[] insertionOrder)
    {
        lightHandles.Clear();
        foreach (int handle in insertionOrder) if (Get(handle).Glow > 0) lightHandles.Add(handle);
        double[] values = new double[lightHandles.Count];
        for (int i = 0; i < values.Length; i++) values[i] = motions[lightHandles[i]].Glow;
        return values;
    }

    public Godot.Collections.Dictionary Light(int index)
    {
        Motion m = Get(lightHandles[index]);
        return new Godot.Collections.Dictionary {
            { "point", m.Point }, { "color", m.Color }, { "energy", m.Glow },
            { "radius", Math.Max(m.Extent.X, m.Extent.Y) * 3.0 + 80.0 }
        };
    }

    // On-demand diagnostic snapshot; never called by the frame preparation path.
    public Godot.Collections.Dictionary Inspect(int handle)
    {
        Motion m = Get(handle);
        Vector2[] points = new Vector2[m.Count];
        System.Array.Copy(m.Points, points, m.Count);
        return new Godot.Collections.Dictionary {
            { "previous", m.Previous }, { "previous_angle", m.PreviousAngle }, { "flow_angle", m.FlowAngle },
            { "point", m.Point }, { "angle", m.Angle }, { "color", m.Color }, { "glow", m.Glow }, { "extent", m.Extent },
            { "last_plume_density", m.LastPlumeDensity },
            { "path", new Godot.Collections.Dictionary { { "points", points } } }
        };
    }

    private Motion Get(int handle) => handle >= 0 && handle < motions.Count && motions[handle] != null
        ? motions[handle] : throw new ArgumentOutOfRangeException(nameof(handle));

    private static double Exposure(double distance, double total, double radius) => total > 0 ? Math.Min(distance, radius * 2.0) / total : 1.0;

    private static float LinearChannel(float v) => v < .04045f ? v * (1.0f / 12.92f) : MathF.Pow((float)((v + .055) * (1.0 / (1.0 + .055))), 2.4f);
    private static Color ToLinear(Color c) => new(LinearChannel(c.R), LinearChannel(c.G), LinearChannel(c.B), c.A);

    private void Pack(Vector2 start, Vector2 end, double radius, Vector2 velocity, double density, double heat,
        double rotation, double spin, Color tint, double coupling, double displacement, double aspect, double dissipation, double emission)
    {
        Vector2 center = (start + end) * .5f;
        double length = (end - start).Length();
        records.Add(center.X); records.Add(center.Y); records.Add((float)(length * .5 + radius)); records.Add((float)radius);
        records.Add(velocity.X); records.Add(velocity.Y); records.Add((float)density); records.Add((float)heat);
        records.Add((float)rotation); records.Add((float)spin); records.Add(2); records.Add(1);
        records.Add(tint.R); records.Add(tint.G); records.Add(tint.B); records.Add((float)coupling);
        records.Add(0); records.Add(0); records.Add(360); records.Add(0);
        records.Add((float)displacement); records.Add((float)length); records.Add((float)aspect); records.Add(240);
        records.Add((float)dissipation); records.Add((float)emission); records.Add(0); records.Add(0);
    }
}
