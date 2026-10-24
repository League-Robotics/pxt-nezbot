namespace lineFollower {
    // Where each reflectance sensor sits, left to right, in mm left of
    // the robot's centre line.
    export const SENSOR_POSITIONS = [30, 6, -6, -30]

    // The bias of a reading that does not show a single line.
    export const NO_LINE = 999

    // How far off centre each kind of reading means, in mm. The table
    // below uses each one for the left side and its negative for the
    // right.
    const BIAS_CENTRED = 0   // the two inner sensors, or all four
    const BIAS_SLIGHT = 6    // one inner sensor
    const BIAS_DRIFT = 10    // three sensors, on a wide line
    const BIAS_OFF = 18      // an inner and an outer sensor
    const BIAS_FAR = 30      // one outer sensor

    // Bias for each sensor reading: how far the middle of the line is
    // from the middle of the robot, in mm, left positive. The index is
    // the reading itself, with bit 0 the LEFT sensor, so the binary
    // digits read right to left across the robot. The picture beside
    // each one is left to right, # where a sensor sees the line.
    const BIAS = [
        NO_LINE,       // 0b0000  ....  nothing seen
        BIAS_FAR,      // 0b0001  #...  line far left
        BIAS_SLIGHT,   // 0b0010  .#..  line slightly left
        BIAS_OFF,      // 0b0011  ##..  line left
        -BIAS_SLIGHT,  // 0b0100  ..#.  line slightly right
        NO_LINE,       // 0b0101  #.#.  not valid: gap between lit sensors
        BIAS_CENTRED,  // 0b0110  .##.  centred
        BIAS_DRIFT,    // 0b0111  ###.  wide line, drifting left
        -BIAS_FAR,     // 0b1000  ...#  line far right
        NO_LINE,       // 0b1001  #..#  not valid: both outer sensors only
        NO_LINE,       // 0b1010  .#.#  not valid: gap between lit sensors
        NO_LINE,       // 0b1011  ##.#  not valid: gap between lit sensors
        -BIAS_OFF,     // 0b1100  ..##  line right
        NO_LINE,       // 0b1101  #.##  not valid: gap between lit sensors
        -BIAS_DRIFT,   // 0b1110  .###  wide line, drifting right
        BIAS_CENTRED,  // 0b1111  ####  centred on a wide line, or a crossing line
    ]

    export function biasOf(bits: number): number {
        return BIAS[bits & 0b1111]
    }

    export function bias(): number {
        return biasOf(calibrate.lineBits())
    }

    // Report what the sensors see, as # for a sensor over the line
    // and . for one that is not, and the bias that gives.
    export function sense(): void {
        const bits = calibrate.lineBits()
        diffDrive.emitLine("sense " + calibrate.barText(bits) + " bias " + biasOf(bits))
    }

    const SPEED = 20          // cm/s
    const STEER = 8            // deg/s of turn for each mm of bias
    const FINISH_AFTER = 200   // cm travelled before looking for the finish
    const ALL_SENSORS = 0b1111
    const LOST_TICKS = 40      // ticks with no line before giving up (about 1 s)

    export const LETTER_F = images.createImage(`
        . # # # .
        . # . . .
        . # # . .
        . # . . .
        . # . . .
        `)

    // Follow the line to the crossbar at the end of the track. Pressing
    // a button stops it.
    export function follow(): void {
        const start = control.millis()
        let lastBias = 0
        let lost = 0
        diffDrive.driveTwist(SPEED, 0)
        while (diffDrive.driveTick()) {
            if (diffDrive.cancelled()) break
            const bits = calibrate.lineBits()
            const travelled = SPEED * (control.millis() - start) / 1000
            if (travelled > FINISH_AFTER && bits == ALL_SENSORS) break

            const b = biasOf(bits)
            lost = b == NO_LINE ? lost + 1 : 0
            if (lost > LOST_TICKS) break
            if (b != NO_LINE) lastBias = b
            diffDrive.driveTwist(SPEED, STEER * lastBias)
            diffDrive.emitLine("sense " + calibrate.barText(bits) + " bias " + lastBias + " steer " + 
            (STEER * lastBias))
        }
        diffDrive.stop()
    }

    // PID steering: the bias is the error. KP turns toward the line in
    // proportion to how far off it is, KD resists fast changes so it
    // does not overshoot, and KI slowly adds up a bias that will not go
    // away. Start with KD and KI at 0 and tune KP first.
    const KP = 4           // deg/s per mm of bias
    const KI = 0             // deg/s per mm of bias, per tick, added up
    const KD = 0            // deg/s per mm of change in bias since the last tick
    const MAX_SUM = 1000     // keeps the added-up bias from growing without limit

    const D_TICKS = 10       // the derivative is the change over this many ticks (about 0.25 s)

    const LOG_EVERY = 4      // ticks between log entries (about 0.1 s)

    let stopRequested = false

    // Stop a running followPID, from a button.
    export function stopRun(): void {
        stopRequested = true
        diffDrive.stop()
    }

    // The last run, recorded ten times a second: the time in ms, the
    // sensors, the bias, the steering and the heading in degrees.
    let log: string[] = []

    // kp, ki, kd and speed replace KP, KI, KD and SPEED for this run; 0
    // keeps the default. Ends with one line giving the run time and the
    // thrash: how much the heading changed per sample, on average, in
    // degrees. A smooth run on a straight line is near 0.
    export function followPID(kp: number, ki: number, kd: number, speed: number): void {
        if (kp == 0) kp = KP
        if (ki == 0) ki = KI
        if (kd == 0) kd = KD
        if (speed == 0) speed = SPEED

        const start = control.millis()
        log = []
        const history: number[] = []             // the last D_TICKS biases
        let lastBias = 0
        let lost = 0
        let sum = 0
        let tick = 0
        let lastHeading = 0
        let swing = 0
        stopRequested = false
        basic.showString("G")
        diffDrive.resetPose()
        diffDrive.driveTwist(speed, 0)
        while (diffDrive.driveTick()) {              // one tick is about 24 ms
            if (stopRequested || diffDrive.cancelled()) break
            const bits = calibrate.lineBits()
            const travelled = speed * (control.millis() - start) / 1000
            if (travelled > FINISH_AFTER && bits == ALL_SENSORS) break

            // With no line in sight, keep steering by the last bias seen
            // and leave the sum alone.
            const reading = biasOf(bits)
            lost = reading == NO_LINE ? lost + 1 : 0
            if (lost > LOST_TICKS) break
            const b = reading == NO_LINE ? lastBias : reading
            lastBias = b
            if (reading != NO_LINE) sum = Math.constrain(sum + b, -MAX_SUM, MAX_SUM)
            history.push(b)
            if (history.length > D_TICKS) history.shift()
            const change = b - history[0]

            const steer = kp * b + ki * sum + kd * change
            diffDrive.driveTwist(speed, steer)
            //diffDrive.emitLine("sense " + calibrate.barText(bits) + " bias " + reading + " steer " + Math.round(steer))
            if (tick % LOG_EVERY == 0) {
                const heading = diffDrive.heading()
                swing += Math.abs(heading - lastHeading)
                lastHeading = heading

            }
            tick++
        }
        diffDrive.stop()

        const samples = Math.floor(tick / LOG_EVERY)
        diffDrive.emitLine("pid kp " + kp + " ki " + ki + " kd " + kd + " speed " + speed
            + " ms " + (control.millis() - start)
            + " thrash " + (samples > 1 ? Math.round(swing / (samples - 1) * 10) / 10 : 0))
    }

    // The pidlog run command: send the last run's log, one line per sample.
    export function sendLog(): void {
        for (const entry of log) {
            diffDrive.emitLine("pid " + entry)
            basic.pause(100)
        }
        diffDrive.emitLine("pid end " + log.length)
    }

    // The followpid run command: RUN followpid <kp> <ki> <kd> <speed>.
    // Runs in the background so the console keeps getting the output.
    export function runFollowPID(): void {
        const kp = diffDrive.runArg(0)
        const ki = diffDrive.runArg(1)
        const kd = diffDrive.runArg(2)
        const speed = diffDrive.runArg(3)
        control.inBackground(function () { followPID(kp, ki, kd, speed) })
    }

    export function register(): void {
        diffDrive.addRunProgram("follow", follow)
        diffDrive.runSignature("follow", "()")
        diffDrive.addRunProgram("followpid", runFollowPID)
        diffDrive.runSignature("followpid", "(kp:number=0, ki:number=0, kd:number=0, speed:number=0)")
        diffDrive.addRunProgram("pidlog", sendLog)
        diffDrive.runSignature("pidlog", "()")
        diffDrive.addRunProgram("sense", sense)
        diffDrive.runSignature("sense", "()")
    }
}
