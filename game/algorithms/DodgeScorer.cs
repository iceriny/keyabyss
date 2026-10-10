using Godot;
using System;

/// <summary>One synchronous batch. Godot objects and combat state stay in GDScript.</summary>
public partial class DodgeScorer : RefCounted
{
    // Profiling at the batch boundary includes Godot array marshaling allocations.
    public long AllocatedBytes() => GC.GetAllocatedBytesForCurrentThread();
    public int CollectionCount() => GC.CollectionCount(0);

    public int Choose(Vector2[] points, int[] starts, int[] segments, double[] radii,
        int count, Vector2[] candidates, Vector2[] travel, double[] scores,
        double[] fixedPenalties, double[] tails, int tailStride)
    {
        if (count < 0 || count > starts.Length || count > segments.Length || count > radii.Length
            || candidates.Length != 24 || travel.Length != 96 || scores.Length != 24
            || fixedPenalties.Length != 24 || tailStride < 2 || tails.Length != 24 * tailStride)
            throw new ArgumentException("Invalid dodge batch dimensions.");

        double bestScore = double.PositiveInfinity;
        int best = 0;
        for (int candidate = 0; candidate < 24; candidate++)
        {
            double ceiling = bestScore - fixedPenalties[candidate]
                + Math.Max(0.000001, bestScore * 0.000000001);
            double score = scores[candidate];
            if (score >= ceiling) continue;
            Vector2 point = candidates[candidate];
            for (int trajectory = 0; trajectory < count; trajectory++)
            {
                double risk = 0.0;
                int start = starts[trajectory];
                double radius = radii[trajectory];
                for (int tick = 0; tick < segments[trajectory]; tick++)
                {
                    Vector2 from = points[start + tick];
                    Vector2 to = points[start + tick + 1];
                    double clearance = point.DistanceTo(Closest(point, from, to)) - radius;
                    double weight = tick < 7 ? 0.25 : tick < 10 ? 0.6 : 1.0;
                    risk = Math.Max(risk, weight * (clearance < 0.0 ? 1600.0 : 120.0 / Math.Max(10.0, clearance)));
                    if (tick < 2 && Sweeps(travel[candidate * 4 + tick * 2], travel[candidate * 4 + tick * 2 + 1], from, to, radius))
                        risk = Math.Max(risk, 100.0);
                    if (risk == 1600.0 || score + risk >= ceiling) break;
                }
                score += risk;
                if (score >= ceiling) break;
            }
            if (score >= ceiling) continue;
            for (int item = 0; item < tailStride; item++) score += tails[candidate * tailStride + item];
            if (score < bestScore)
            {
                bestScore = score;
                best = candidate;
            }
        }
        return best;
    }

    // Match Godot 4.7.2 Geometry2D's real_t intermediates and degenerate cutoff.
    private static Vector2 Closest(Vector2 point, Vector2 from, Vector2 to)
    {
        Vector2 offset = point - from;
        Vector2 travel = to - from;
        float lengthSquared = travel.LengthSquared();
        if (lengthSquared < 1e-20f) return from;
        float fraction = travel.Dot(offset) / lengthSquared;
        if (fraction <= 0.0f) return from;
        if (fraction >= 1.0f) return to;
        return from + travel * fraction;
    }

    // Same float32 vectors / float64 scalar arithmetic as CombatGeometry.sweep_discs.
    private static bool Sweeps(Vector2 aFrom, Vector2 aTo, Vector2 bFrom, Vector2 bTo, double radius)
    {
        Vector2 offset = aFrom - bFrom;
        double c = offset.LengthSquared() - radius * radius;
        if (c <= 0.0) return true;
        Vector2 travel = (aTo - aFrom) - (bTo - bFrom);
        double a = travel.LengthSquared();
        double b = offset.Dot(travel);
        if (a <= 0.000001 || b >= 0.0) return false;
        double discriminant = b * b - a * c;
        return discriminant >= 0.0 && c / (-b + Math.Sqrt(discriminant)) <= 1.0;
    }
}
