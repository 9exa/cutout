# Async Batch Processing Design
**Status**: Future Feature - Not Immediate Priority
**Last Updated**: 2026-02-11

## Overview
Design for handling hundreds of simultaneous destructions with automatic frame budget management and progress feedback via Godot signals.

## Use Case Requirements

### Primary Use Case: Gameplay Mass Destruction
- Hundreds of objects fracturing simultaneously
- No frame drops or stuttering
- Automatic frame budget management (no manual configuration needed)
- Results delivered via Godot signals as they complete
- FIFO queue processing order

### Key Requirements
1. **Automatic Frame Management**: System adapts dynamically, no manual tuning
2. **Progress Feedback**: Godot signals for job completion/progress
3. **Queue Behavior**: FIFO processing with priority support
4. **High Throughput**: Handle 100+ destructions without performance degradation

## Proposed Architecture

### Hybrid Approach: GDScript Queue + Rust Parallel Processor

```
┌─────────────────────────────────────────────────────────┐
│ GDScript Layer (CutoutBatchProcessor autoload)          │
│ - Job queue management (FIFO)                           │
│ - Signal emission for progress/completion               │
│ - Adaptive frame budget monitoring                      │
│ - High-level API for game developers                    │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ Rust GDExtension (CutoutBatchNative)                    │
│ - Parallel processing with Rayon thread pool            │
│ - Lock-free work stealing                               │
│ - Efficient polygon operations                          │
│ - Returns results as they complete                      │
└─────────────────────────────────────────────────────────┘
```

## API Design

### Three-Tier Approach

#### 1. High-Level Helpers (Easiest)
```gdscript
# Automatically queues, processes, and applies results
await CutoutBatch.fracture_object(destructible_object, fracture_params)

# Batch multiple operations
var batch = CutoutBatch.create()
batch.add_fracture(obj1, params1)
batch.add_fracture(obj2, params2)
await batch.execute()  # Handles everything automatically
```

#### 2. Explicit Batch API (More Control)
```gdscript
# Submit job and get job ID
var job_id = CutoutBatch.submit_fracture(polygon_data, fracture_params)

# Listen for completion
CutoutBatch.job_completed.connect(_on_fracture_completed)

func _on_fracture_completed(job_id: int, result: Array):
    # Handle result
```

#### 3. Async Streaming (Maximum Performance)
```gdscript
# For very large batches - process as stream
var stream = CutoutBatch.create_stream()
for obj in hundreds_of_objects:
    stream.push(obj.get_polygon_data(), fracture_params)

stream.results_ready.connect(_on_batch_results)
stream.start()  # Processes in background with adaptive throttling

func _on_batch_results(results: Array):
    # Receive results in chunks as they complete
```

## Implementation Details

### Rust Side: `CutoutBatchNative`

```rust
use godot::prelude::*;
use rayon::prelude::*;
use std::sync::Arc;

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct CutoutBatchNative {
    #[base]
    base: Base<RefCounted>,
}

#[godot_api]
impl CutoutBatchNative {
    /// Process multiple fracture operations in parallel
    /// Returns results in same order as input (maintains FIFO)
    #[func]
    pub fn process_batch_parallel(
        &self,
        polygons: Array<PackedVector2Array>,
        params: Array<Dictionary>
    ) -> Array<Array<PackedVector2Array>> {
        // Convert Godot arrays to Rust Vec for parallel processing
        let polygon_vec: Vec<_> = polygons.iter_shared().collect();
        let params_vec: Vec<_> = params.iter_shared().collect();

        // Parallel processing with Rayon
        let results: Vec<_> = polygon_vec
            .par_iter()
            .zip(params_vec.par_iter())
            .map(|(polygon, param)| {
                // Perform fracture operation
                self.fracture_single(polygon, param)
            })
            .collect();

        // Convert back to Godot Array
        results.into_iter().collect()
    }

    /// Process with work-stealing for variable-time jobs
    #[func]
    pub fn process_batch_streaming(
        &self,
        polygons: Array<PackedVector2Array>,
        params: Array<Dictionary>,
        chunk_size: i32
    ) -> Array<Array<PackedVector2Array>> {
        // Process in chunks to avoid blocking for too long
        let chunk_size = chunk_size as usize;
        let polygon_vec: Vec<_> = polygons.iter_shared().collect();
        let params_vec: Vec<_> = params.iter_shared().collect();

        let results: Vec<_> = polygon_vec
            .par_chunks(chunk_size)
            .zip(params_vec.par_chunks(chunk_size))
            .flat_map(|(poly_chunk, param_chunk)| {
                poly_chunk
                    .par_iter()
                    .zip(param_chunk.par_iter())
                    .map(|(p, param)| self.fracture_single(p, param))
                    .collect::<Vec<_>>()
            })
            .collect();

        results.into_iter().collect()
    }
}
```

### GDScript Side: `CutoutBatchProcessor` Autoload

```gdscript
# res://addons/cutout/autoload/cutout_batch_processor.gd
extends Node

## Signals for async batch processing
signal job_completed(job_id: int, result: Array)
signal job_progress(job_id: int, progress: float)
signal batch_completed(batch_id: int, results: Array)

## Configuration
const TARGET_FRAME_TIME_MS := 16.0  # ~60 FPS
const MIN_FRAME_TIME_MS := 8.0      # Safety margin
const SAFETY_MARGIN := 0.8          # Use 80% of available time

## Internal state
var _job_queue: Array[Dictionary] = []
var _next_job_id := 0
var _batch_native: CutoutBatchNative
var _processing := false

## Adaptive throttling
var _avg_job_time_ms := 1.0
var _adaptive_batch_size := 10

func _ready() -> void:
    _batch_native = CutoutBatchNative.new()
    set_process(true)

func _process(_delta: float) -> void:
    if _job_queue.is_empty():
        return

    # Calculate how much time we have this frame
    var frame_start := Time.get_ticks_usec()
    var available_time_ms := TARGET_FRAME_TIME_MS * SAFETY_MARGIN

    # Process jobs until we run out of time
    var processed_count := 0
    while not _job_queue.is_empty():
        var job := _job_queue[0] as Dictionary

        # Check if we have time for this job
        var estimated_time := _avg_job_time_ms
        var elapsed_ms := (Time.get_ticks_usec() - frame_start) / 1000.0
        if elapsed_ms + estimated_time > available_time_ms:
            break  # Not enough time, continue next frame

        # Process the job
        var job_start := Time.get_ticks_usec()
        var result = _process_job(job)
        var job_time := (Time.get_ticks_usec() - job_start) / 1000.0

        # Update adaptive metrics
        _update_metrics(job_time)

        # Emit completion signal
        job_completed.emit(job.id, result)

        _job_queue.pop_front()
        processed_count += 1

    # Adaptive batch size adjustment
    if processed_count > 0:
        _adjust_batch_size(processed_count)

func submit_fracture(polygon: PackedVector2Array, params: Dictionary) -> int:
    var job_id := _next_job_id
    _next_job_id += 1

    _job_queue.push_back({
        "id": job_id,
        "type": "fracture",
        "polygon": polygon,
        "params": params
    })

    return job_id

func submit_batch(polygons: Array, params: Array) -> int:
    # For large batches, use Rust parallel processing
    if polygons.size() > _adaptive_batch_size:
        return _submit_parallel_batch(polygons, params)
    else:
        # For small batches, queue individually
        var batch_id := _next_job_id
        for i in polygons.size():
            submit_fracture(polygons[i], params[i])
        return batch_id

func _submit_parallel_batch(polygons: Array, params: Array) -> int:
    var job_id := _next_job_id
    _next_job_id += 1

    _job_queue.push_back({
        "id": job_id,
        "type": "batch_parallel",
        "polygons": polygons,
        "params": params
    })

    return job_id

func _process_job(job: Dictionary) -> Variant:
    match job.type:
        "fracture":
            return _batch_native.fracture(job.polygon, job.params)
        "batch_parallel":
            return _batch_native.process_batch_parallel(job.polygons, job.params)
        _:
            push_error("Unknown job type: " + str(job.type))
            return null

func _update_metrics(job_time_ms: float) -> void:
    # Exponential moving average
    const ALPHA := 0.2
    _avg_job_time_ms = ALPHA * job_time_ms + (1.0 - ALPHA) * _avg_job_time_ms

func _adjust_batch_size(processed_count: int) -> void:
    # If we processed fewer jobs than expected, increase batch size
    # If we processed many jobs easily, increase batch size
    if processed_count < _adaptive_batch_size / 2:
        _adaptive_batch_size = max(5, _adaptive_batch_size - 2)
    elif processed_count >= _adaptive_batch_size:
        _adaptive_batch_size = min(100, _adaptive_batch_size + 5)
```

## Performance Characteristics

### Expected Performance
- **Parallel Speedup**: Near-linear scaling up to CPU core count
- **Frame Budget**: Adaptive, targets 60 FPS with safety margin
- **Throughput**: 100+ destructions per second on modern hardware (8+ cores)
- **Latency**: Results available within 1-3 frames for typical operations

### Memory Considerations
- **Queue Size**: Bounded to prevent memory exhaustion
- **Batch Chunking**: Large batches processed in chunks
- **Result Streaming**: Results can be delivered incrementally

## Testing Strategy

### Performance Benchmarks
1. Measure throughput: X destructions/second
2. Measure frame time impact: Average, p95, p99
3. Stress test: 500+ simultaneous destructions
4. Memory profiling: Peak usage under load

### Integration Tests
1. Verify FIFO order preservation
2. Test signal emission timing
3. Validate result correctness under parallel execution
4. Test adaptive throttling behavior

## Future Enhancements

### Priority Queue (Optional)
```gdscript
# Support for priority-based processing
CutoutBatch.submit_fracture(polygon, params, priority=10)
```

### Cancellation (Optional)
```gdscript
# Allow cancelling queued jobs
CutoutBatch.cancel_job(job_id)
```

### Progress Reporting (Optional)
```gdscript
# For very long operations
CutoutBatch.job_progress.connect(func(job_id, progress):
    print("Job %d: %d%% complete" % [job_id, progress * 100])
)
```

## Implementation Notes

### Why Hybrid Approach?
- **GDScript Queue**: Natural integration with Godot's signal system, easy frame timing
- **Rust Parallel**: Maximum performance for CPU-intensive operations
- **Best of Both**: Godot-friendly API with native performance

### Rayon Benefits
- Automatic work stealing
- Lock-free parallelism
- Panic safety
- Efficient thread pool reuse

### Frame Budget Strategy
- **Adaptive**: Learns job timing over time
- **Conservative**: Safety margin prevents frame drops
- **Responsive**: Adjusts batch size dynamically

## Open Questions (To Resolve During Implementation)

1. Should we expose thread pool size configuration?
2. How to handle pathological cases (e.g., one job takes 100ms)?
3. Should results be cached for identical operations?
4. Priority queue implementation details?
5. Max queue size before blocking/dropping jobs?

## Dependencies

- Rust: `rayon = "1.8"` (already added to Cargo.toml)
- Godot: Signals, autoload system
- GDExtension: Thread-safe variants (already enabled with `experimental-threads`)

---

**Note**: This design document captures the discussion from 2026-02-11. Implementation deferred pending further consideration of use cases and priorities.
