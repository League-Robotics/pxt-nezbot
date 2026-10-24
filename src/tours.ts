namespace tours {
    // Drive a circle of this radius, turning left.
    export function circle(radius: number): void {
        diffDrive.moveLeg(2 * Math.PI * radius, 360)
        diffDrive.stop()
    }

    // Drive a square with sides this long, turning left at each corner.
    export function square(side: number): void {
        for (let i = 0; i < 4; i++) {
            if (!diffDrive.moveLeg(side, 0)) break
            if (!diffDrive.moveLeg(0, 90)) break
        }
        diffDrive.stop()
    }

    export function register(): void {
        diffDrive.addRunProgram("circle", function () { circle(diffDrive.runArgOr(0, 20, 0)) })
        diffDrive.runSignature("circle", "(radius_cm:number=20)")
        diffDrive.addRunProgram("square", function () { square(diffDrive.runArgOr(0, 30, 0)) })
        diffDrive.runSignature("square", "(side_cm:number=30)")
    }
}
