import
  std/math,
  vmath

const
  MotionWindow = 0.1
  MotionSamples = 16

type
  MotionSample = object
    position: Vec2
    timestamp: float64

  PointerMotion* = object
    ## Retains bounded native samples independently of UI frame timing.
    samples: array[MotionSamples, MotionSample]
    count: int
    direction: Vec2
    velocity*: Vec2

proc clear*(motion: var PointerMotion) =
  ## Forgets velocity and samples when pointer ownership changes.
  motion.count = 0
  motion.direction = vec2(0)
  motion.velocity = vec2(0)

proc dropFirst(motion: var PointerMotion) =
  ## Removes the oldest sample from the small chronological buffer.
  for i in 1 ..< motion.count:
    motion.samples[i - 1] = motion.samples[i]
  dec motion.count

proc sample*(
  motion: var PointerMotion,
  position: Vec2,
  timestamp: float64,
  maximumSpeed: float32
) =
  ## Estimates recent velocity from native event time, including lift pauses.
  if timestamp.classify in {fcNan, fcInf, fcNegInf} or timestamp < 0 or
    position.x.classify in {fcNan, fcInf, fcNegInf} or
    position.y.classify in {fcNan, fcInf, fcNegInf}:
      motion.clear()
      return
  if motion.count > 0:
    let previous = motion.samples[motion.count - 1]
    if timestamp == previous.timestamp:
      # Repeated event times provide no new velocity information.
      return
    if timestamp < previous.timestamp:
      motion.clear()
    else:
      let delta = position - previous.position
      if dot(delta, motion.direction) < 0:
        # A reversal should follow the new direction without old momentum.
        motion.samples[0] = previous
        motion.count = 1
      if delta != vec2(0):
        motion.direction = delta
  if motion.count == MotionSamples:
    motion.dropFirst()
  motion.samples[motion.count] = MotionSample(
    position: position, timestamp: timestamp
  )
  inc motion.count
  motion.velocity = vec2(0)
  if motion.count < 2:
    return

  let cutoff = timestamp - MotionWindow
  while motion.count > 2 and motion.samples[1].timestamp <= cutoff:
    motion.dropFirst()
  var first = motion.samples[0]
  if first.timestamp < cutoff:
    let
      following = motion.samples[1]
      fraction = (cutoff - first.timestamp) /
        (following.timestamp - first.timestamp)
    first.position += (following.position - first.position) * fraction.float32
    first.timestamp = cutoff
  let duration = timestamp - first.timestamp
  if duration < 0.001:
    return
  motion.velocity = (position - first.position) / duration.float32
  let speed = motion.velocity.length
  if speed > maximumSpeed:
    motion.velocity *= max(0.0'f, maximumSpeed) / speed
