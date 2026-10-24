diffDrive.setupRobot()

// Comunication configuration
diffDrive.setupRadioForName(control.deviceName())
diffDrive.setupWifi("Robot_Garage", "****")
diffDrive.setupWifiForName(control.deviceName())

// Robot Calibration
diffDrive.setWheelCalibration(89.88 * Math.PI / 360)  // wheel diameter 89.88 mm
diffDrive.setTrackWidth(11.45)  // measured track width, cm
diffDrive.setConfigValue(ConfigField.RotationalSlip, .95)  
calibrate.setupCalibrations()
lineFollower.register()
tours.register()

// A runs the PID follower with the default gains, B stops it.
input.onButtonPressed(Button.A, function () { lineFollower.followPID(0, 0, 0, 0) })
input.onButtonPressed(Button.B, function () { lineFollower.stopRun() })
