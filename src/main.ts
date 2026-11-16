diffDrive.setupRobot()

// Comunication configuration
diffDrive.setupWifi("Robot_Garage", "****")
diffDrive.setupWifiForName(control.deviceName())

calibrate.setupCalibrations()
lineFollower.register()
tours.register()

// A runs the PID follower with the default gains, B stops it.
input.onButtonPressed(Button.A, function () { lineFollower.followPID(0, 0, 0, 0) })
input.onButtonPressed(Button.B, function () { lineFollower.stopRun() })
