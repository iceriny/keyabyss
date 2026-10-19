using Godot;
using System;
using System.Threading.Tasks;

/// <summary>One synchronous batch. Godot objects and combat state stay in GDScript.</summary>
public partial class DodgeScorer : RefCounted
{
    private Vector2[] _points = Array.Empty<Vector2>();
    private int[] _starts = Array.Empty<int>();
    private readonly double[] _bestScores = new double[4];
    private readonly int[] _bestIndices = new int[4];
    private int _workerLimit = Math.Clamp(System.Environment.ProcessorCount / 2, 1, 4);

    public void SetWorkerLimit(int count) => _workerLimit = Math.Clamp(count, 1, 4);

    public int ChooseFlight(Vector2[] origins, Vector2[] velocities, double[] flight,
        int[] segments, double[] radii, int count, Vector2[] candidates, Vector2[] travel,
        double[] scores, double[] fixedPenalties, double[] tails, int tailStride)
    {
        if (count < 0 || count > origins.Length || count > velocities.Length
            || count * 2 > flight.Length || count > segments.Length || count > radii.Length)
            throw new ArgumentException("Invalid flight batch dimensions.");
        if (_starts.Length < count)
        {
            Array.Resize(ref _starts, count);
            Array.Resize(ref _points, count * 15);
        }
        // Workers own disjoint numeric slices. No scene objects, RNG or events.
        int jobs = Math.Clamp(count / 128, 1, _workerLimit);
        void Predict(int job)
        {
            for (int i = count * job / jobs; i < count * (job + 1) / jobs; i++)
            {
                if (segments[i] < 0 || segments[i] > 14)
                    throw new ArgumentException("Invalid prediction horizon.");
                int start = i * 15;
                _starts[i] = start;
                _points[start] = origins[i];
                Vector2 velocity = velocities[i];
                double turn = flight[i * 2];
                double growth = flight[i * 2 + 1];
                double denominator = growth * growth + turn * turn;
                double angle = turn * 0.1;
                double scale = Math.Exp(growth * 0.1);
                double along = denominator < 0.00000001 ? 0.1
                    : (scale * (growth * Math.Cos(angle) + turn * Math.Sin(angle)) - growth) / denominator;
                double across = denominator < 0.00000001 ? 0.0
                    : (scale * (growth * Math.Sin(angle) - turn * Math.Cos(angle)) + turn) / denominator;
                for (int tick = 0; tick < segments[i]; tick++)
                {
                    Vector2 displacement = velocity * (float)along;
                    if (denominator >= 0.00000001)
                        displacement += new Vector2(-velocity.Y, velocity.X) * (float)across;
                    _points[start + tick + 1] = _points[start + tick] + displacement;
                    velocity = velocity.Rotated((float)angle) * (float)scale;
                }
            }
        }
        if (jobs == 1) Predict(0);
        else Parallel.For(0, jobs, new ParallelOptions { MaxDegreeOfParallelism = jobs }, Predict);
        // Score only after all trajectories are complete; no partial frame results.
        return Choose(_points, _starts, segments, radii, count, candidates, travel,
            scores, fixedPenalties, tails, tailStride);
    }

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

        double Evaluate(int candidate, double bestScore)
        {
            double ceiling = bestScore - fixedPenalties[candidate]
                + Math.Max(0.000001, bestScore * 0.000000001);
            double score = scores[candidate];
            if (score >= ceiling) return double.PositiveInfinity;
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
            if (score >= ceiling) return double.PositiveInfinity;
            for (int item = 0; item < tailStride; item++) score += tails[candidate * tailStride + item];
            return score;
        }
        // Seed every chunk with the same first candidate. Each chunk keeps local
        // incumbent pruning; reduction in candidate order preserves exact ties.
        double bestScore = Evaluate(0, double.PositiveInfinity);
        int best = 0;
        int jobs = Math.Clamp(count / 128, 1, _workerLimit);
        void Score(int job)
        {
            double localScore = bestScore;
            int localBest = 0;
            for (int candidate = 1 + 23 * job / jobs; candidate < 1 + 23 * (job + 1) / jobs; candidate++)
            {
                double score = Evaluate(candidate, localScore);
                if (score < localScore)
                {
                    localScore = score;
                    localBest = candidate;
                }
            }
            _bestScores[job] = localScore;
            _bestIndices[job] = localBest;
        }
        if (jobs == 1) Score(0);
        else Parallel.For(0, jobs, new ParallelOptions { MaxDegreeOfParallelism = jobs }, Score);
        for (int job = 0; job < jobs; job++)
            if (_bestScores[job] < bestScore)
            {
                bestScore = _bestScores[job];
                best = _bestIndices[job];
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
