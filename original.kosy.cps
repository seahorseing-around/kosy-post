/**
  Copyright (C) 2012-2023 by Autodesk, Inc.
  All rights reserved.

  KOSY post processor configuration.

  $Revision: 44104 165ed1a9c77e5601dab85a96f32381c0b4a83b25 $
  $Date: 2023-12-14 12:10:48 $

  FORKID {793B9330-BD83-4d9c-B9A2-DB45CFF321E5}
*/

description = "KOSY";
vendor = "MAXcomputer GmbH ";
vendorUrl = "http://www.max-computer.de";
legal = "Copyright (C) 2012-2023 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 45917;

longDescription = "This is a generic post for the KOSY CNC. Manual tool change is required after the M1 command. The first tool must be selected prior to running the program. Spindle speeds are ignored in the original toolpath as these are not supported by KOSY.";

extension = "knc";
setCodePage("ascii");

capabilities = CAPABILITY_MILLING | CAPABILITY_MACHINE_SIMULATION;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

// user-defined properties
properties = {
  separateWordsWithSpace: {
    title      : "Separate words with space",
    description: "Adds spaces between words if 'yes' is selected.",
    group      : "formats",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  useComments: {
    title      : "Output comments",
    description: "Enable to allow the usage of comments.",
    group      : "formats",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  useG77: {
    title      : "Use G77",
    description: "Enable to output G77 at the end of the program.",
    group      : "homePositions",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  safePositionMethod: {
    title      : "Safe Retracts",
    description: "Select your desired retract option. 'Clearance Height' retracts to the operation clearance height.",
    group      : "homePositions",
    type       : "enum",
    values     : [
      {title:"Clearance Height", id:"clearanceHeight"}
    ],
    value: "clearanceHeight",
    scope: "post"
  },
};

// wcs definiton
wcsDefinitions = {
  useZeroOffset: false,
  wcs          : [
    {name:"Standard", format:"#", range:[1, 1]}
  ]
};

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 2 : 3), forceDecimal:true});
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2), forceDecimal:true});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var m30Format = createFormat({decimals:0}); // 1/18th seconds
var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createOutputVariable({onchange:function() {state.retractedX = false;}, prefix:"X"}, xyzFormat);
var yOutput = createOutputVariable({onchange:function() {state.retractedY = false;}, prefix:"Y"}, xyzFormat);
var zOutput = createOutputVariable({onchange:function() {state.retractedZ = false;}, prefix:"Z"}, xyzFormat);
var aOutput = createOutputVariable({prefix:"A"}, abcFormat);
var bOutput = createOutputVariable({prefix:"B"}, abcFormat);
var cOutput = createOutputVariable({prefix:"C"}, abcFormat);
var feedOutput = createOutputVariable({prefix:"F"}, feedFormat);

// circular output
var iOutput = createOutputVariable({prefix:"I", control:CONTROL_FORCE}, xyzFormat);
var jOutput = createOutputVariable({prefix:"J", control:CONTROL_FORCE}, xyzFormat);

var gMotionModal = createOutputVariable({control:CONTROL_FORCE}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createOutputVariable({onchange:function () {forceModals(gMotionModal);}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createOutputVariable({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createOutputVariable({}, gFormat); // modal group 5 // G93-94
var gCycleModal = createOutputVariable({control:CONTROL_FORCE}, gFormat); // modal group 9 // G81, ...

var settings = {
  retract: {
    cancelRotationOnRetracting: false, // specifies that rotations (G68) need to be canceled prior to retracting
    methodXY                  : undefined, // special condition, overwrite retract behavior per axis
    methodZ                   : undefined, // special condition, overwrite retract behavior per axis
    useZeroValues             : ["G76"], // enter property value id(s) for using "0" value instead of machineConfiguration axes home position values (ie G30 Z0)
    homeXY                    : {onIndexing:false, onToolChange:false, onProgramEnd:{axes:[X, Y]}} // Specifies when the machine should be homed in X/Y. Sample: onIndexing:{axes:[X, Y], singleLine:false}
  },
  machineAngles: { // refer to https://cam.autodesk.com/posts/reference/classMachineConfiguration.html#a14bcc7550639c482492b4ad05b1580c8
    controllingAxis: ABC,
    type           : PREFER_PREFERENCE,
    options        : ENABLE_ALL
  },
  workPlaneMethod: {
    useTiltedWorkplane    : false, // specifies that tilted workplanes should be used (ie. G68.2, G254, PLANE SPATIAL, CYCLE800), can be overwritten by property
    eulerConvention       : EULER_ZXZ_R, // specifies the euler convention (ie EULER_XYZ_R), set to undefined to use machine angles for TWP commands ('undefined' requires machine configuration)
    eulerCalculationMethod: "standard", // ('standard' / 'machine') 'machine' adjusts euler angles to match the machines ABC orientation, machine configuration required
    cancelTiltFirst       : true, // cancel tilted workplane prior to WCS (G54-G59) blocks
    useABCPrepositioning  : false, // position ABC axes prior to tilted workplane blocks
    forceMultiAxisIndexing: false, // force multi-axis indexing for 3D programs
    optimizeType          : undefined // can be set to OPTIMIZE_NONE, OPTIMIZE_BOTH, OPTIMIZE_TABLES, OPTIMIZE_HEADS, OPTIMIZE_AXIS. 'undefined' uses legacy rotations
  },
  comments: {
    permittedCommentChars: " abcdefghijklmnopqrstuvwxyz0123456789.,=_-", // letters are not case sensitive, use option 'outputFormat' below. Set to 'undefined' to allow any character
    prefix               : "; ", // specifies the prefix for the comment
    suffix               : "", // specifies the suffix for the comment
    outputFormat         : "ignoreCase", // can be set to "upperCase", "lowerCase" and "ignoreCase". Set to "ignoreCase" to write comments without upper/lower case formatting
    maximumLineLength    : 80 // the maximum number of characters allowed in a line, set to 0 to disable comment output
  },
  maximumSequenceNumber       : undefined, // the maximum sequence number (Nxxx), use 'undefined' for unlimited
  supportsRadiusCompensation  : false, // specifies if radius compensation is supported on the control
  supportsOptionalBlocks      : false, // specifies if optional block output is supported
  outputToolLengthCompensation: false, // specifies if tool length compensation code should be output (G43)
  outputToolLengthOffset      : false, // specifies if tool length offset code should be output (Hxx)
  supportsInverseTimeFeed     : false, // specifies if inverse time feedrates are supported by the postprocessor
  supportsTCP                 : false // specifies if the postprocessor does support TCP
};

function onOpen() {
  // define and enable machine configuration
  receivedMachineConfiguration = machineConfiguration.isReceived();
  if (typeof defineMachine == "function") {
    defineMachine(); // hardcoded machine configuration
  }
  activateMachine(); // enable the machine optimizations and settings
  if (!getProperty("separateWordsWithSpace")) {
    setWordSeparator("");
  }

  gPlaneModal.disable(); // Planes are not supported
  gFeedModeModal.disable(); // Feedmodes are not supported

  if (!getProperty("useComments")) {
    settings.comments.maximumLineLength = 0;
  }
  // required header
  writeBlock("_");
  writeBlock("_");

  writeComment(programName);
  writeComment(programComment);
  writeProgramHeader();

  // absolute coordinates
  writeBlock(gAbsIncModal.format(90));
  writeBlock(gFormat.format(76));
  // writeBlock(gUnitModal.format(unit == MM ? 21 : 20));
  validateCommonParameters();
}

function onSection() {
  var forceToolAndRetract = optionalSection && !currentSection.isOptional();
  optionalSection = currentSection.isOptional();
  var insertToolCall = isToolChangeNeeded("number") || forceToolAndRetract;
  var newWorkOffset = isNewWorkOffset();
  var newWorkPlane = isNewWorkPlane();
  if ((insertToolCall || newWorkOffset || newWorkPlane)) {
    if (!isFirstSection()) {
      writeRetract(Z); // retract
    } else {
      state.retractedZ = true;
    }
  }

  writeComment(getParameter("operation-comment", ""));

  // tool change
  writeToolCall(tool, insertToolCall);
  onCommand(COMMAND_START_SPINDLE);

  forceXYZ();

  var abc = defineWorkPlane(currentSection, true);

  forceAny();

  // prepositioning
  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  var isRequired = insertToolCall || state.retractedZ || (!isFirstSection() && getPreviousSection().isMultiAxis());
  writeInitialPositioning(initialPosition, isRequired);
}

function onDwell(seconds) {
  var maxValue = 99999.999;
  if (seconds > maxValue) {
    warning(subst(localize("Dwelling time of '%1' exceeds the maximum value of '%2' in operation '%3'"), seconds, maxValue, getParameter("operation-comment", "")));
  }
  seconds = Math.ceil(seconds * 18);
  writeBlock(mFormat.format(30), "P" + m30Format.format(seconds));
}

function onSpindleSpeed(spindleSpeed) {
}

function onCycle() {
}

function getCommonCycle(x, y, z, r) {
  forceXYZ();
  return [xOutput.format(x), yOutput.format(y),
    zOutput.format(z),
    "B" + xyzFormat.format(r)];
}

function onCyclePoint(x, y, z) {
  if (!isSameDirection(machineConfiguration.getSpindleAxis(), getForwardDirection(currentSection))) {
    expandCyclePoint(x, y, z);
    return;
  }

  // check if we can group the drilling or not
  var cycleRequiresRetract = xyzFormat.areDifferent(cycle.retract, cycle.clearance);
  if (isFirstCyclePoint() || cycleRequiresRetract) {
    // return to initial Z which is clearance plane and set absolute mode
    repositionToCycleClearance(cycle, getCurrentPosition().x, getCurrentPosition().y, z);

    switch (cycleType) {
    case "drilling":
      writeBlock(
        gAbsIncModal.format(90), gCycleModal.format(81),
        getCommonCycle(x, y, z, cycle.retract),
        feedOutput.format(cycle.feedrate)
      );
      break;
    default:
      expandCyclePoint(x, y, z);
    }
    if (cycleRequiresRetract && !cycleExpanded) {
      writeBlock(gCycleModal.format(80));
      gMotionModal.reset();
    }
  } else {
    if (cycleExpanded) {
      expandCyclePoint(x, y, z);
    } else {
      var _x = xOutput.format(x);
      var _y = yOutput.format(y);
      if (!_x && !_y) {
        xOutput.reset(); // at least one axis is required
        _x = xOutput.format(x);
      }
      writeBlock(gFormat.format(79), _x, _y);
    }
  }
}

function onCycleEnd() {
  if (!cycleExpanded) {
    zOutput.reset();
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  // force both X/Y for G2/G3

  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }

  var start = getCurrentPosition();

  if (isFullCircle()) {
    if (isHelical()) {
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      xOutput.reset();
      yOutput.reset();
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), iOutput.format(cx - start.x), jOutput.format(cy - start.y), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
    case PLANE_XY:
      xOutput.reset();
      yOutput.reset();
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x), jOutput.format(cy - start.y), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  }
}

var mapCommand = {
  COMMAND_STOP         : 1,
  COMMAND_OPTIONAL_STOP: 5
};

function onCommand(command) {
  switch (command) {
  case COMMAND_COOLANT_OFF:
    return;
  case COMMAND_COOLANT_ON:
    return;
  case COMMAND_START_SPINDLE:
    if (!tool.clockwise) {
      error(localize("Counter clockwise spindle rotation is not supported"));
    }
    writeBlock(mFormat.format(10), "O6.1");
    return;
  case COMMAND_LOAD_TOOL:
    onCommand(COMMAND_STOP);
    writeComment("MANUAL TOOL CHANGE TO T" + toolFormat.format(tool.number));
    writeComment(tool.comment);
    return;
  case COMMAND_STOP_SPINDLE:
    writeBlock(mFormat.format(10), "O6.0");
    return;
  case COMMAND_LOCK_MULTI_AXIS:
    return;
  case COMMAND_UNLOCK_MULTI_AXIS:
    return;
  case COMMAND_BREAK_CONTROL:
    return;
  case COMMAND_TOOL_MEASURE:
    return;
  }

  var stringId = getCommandStringId(command);
  var mcode = mapCommand[stringId];
  if (mcode != undefined) {
    writeBlock(mFormat.format(mcode));
  } else {
    onUnsupportedCommand(command);
  }
}

function onSectionEnd() {
  forceAny();
}

function writeRetract() {
  var retract = getRetractParameters.apply(this, arguments);
  if (retract && retract.words.length > 0) {
    if (typeof gRotationModal != "undefined" && gRotationModal.getCurrent() == 68 && settings.retract.cancelRotationOnRetracting) { // cancel rotation before retracting
      cancelWorkPlane(true);
    }
    for (var i in retract.words) {
      var words = retract.singleLine ? retract.words : retract.words[i];
      switch (retract.method) {
      case "G76":
        writeBlock(gFormat.format(76), words);
        break;
      default:
        error(subst(localize("Unsupported safe position method '%1'"), retract.method));
        return;
      }
      if (retract.singleLine) {
        break;
      }
    }
  }
}

function onClose() {
  optionalSection = false;
  onCommand(COMMAND_STOP_SPINDLE);
  if (getProperty("useG77")) {
    writeBlock(gFormat.format(77));
  } else {
    writeRetract(Z);
    if (getSetting("retract.homeXY.onProgramEnd", false)) {
      writeRetract(settings.retract.homeXY.onProgramEnd);
    }
  }
  setWorkPlane(new Vector(0, 0, 0)); // reset working plane
  writeBlock(gFormat.format(99)); // end of program
}

// >>>>> INCLUDED FROM include_files/commonFunctions.cpi
// internal variables, do not change
var receivedMachineConfiguration;
var tcp = {isSupportedByControl:getSetting("supportsTCP", true), isSupportedByMachine:false, isSupportedByOperation:false};
var state = {
  retractedX              : false, // specifies that the machine has been retracted in X
  retractedY              : false, // specifies that the machine has been retracted in Y
  retractedZ              : false, // specifies that the machine has been retracted in Z
  lengthCompensationActive: false, // specifies that tool length compensation is active
  mainState               : true // specifies the current context of the state (true = main, false = optional)
};
var validateLengthCompensation = getSetting("outputToolLengthCompensation", true); // disable validation when outputToolLengthCompensation is disabled
var multiAxisFeedrate;
var sequenceNumber;
var optionalSection = false;
var currentWorkOffset;
var forceSpindleSpeed = false;
var operationNeedsSafeStart = false; // used to convert blocks to optional for safeStartAllOperations

function activateMachine() {
  // disable unsupported rotary axes output
  if (!machineConfiguration.isMachineCoordinate(0) && (typeof aOutput != "undefined")) {
    aOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(1) && (typeof bOutput != "undefined")) {
    bOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(2) && (typeof cOutput != "undefined")) {
    cOutput.disable();
  }

  // setup usage of useTiltedWorkplane
  settings.workPlaneMethod.useTiltedWorkplane = getProperty("useTiltedWorkplane") != undefined ? getProperty("useTiltedWorkplane") :
    getSetting("workPlaneMethod.useTiltedWorkplane", false);
  settings.workPlaneMethod.useABCPrepositioning = getProperty("useABCPrepositioning") != undefined ? getProperty("useABCPrepositioning") :
    getSetting("workPlaneMethod.useABCPrepositioning", false);

  if (!machineConfiguration.isMultiAxisConfiguration()) {
    return; // don't need to modify any settings for 3-axis machines
  }

  // identify if any of the rotary axes has TCP enabled
  var axes = [machineConfiguration.getAxisU(), machineConfiguration.getAxisV(), machineConfiguration.getAxisW()];
  tcp.isSupportedByMachine = axes.some(function(axis) {return axis.isEnabled() && axis.isTCPEnabled();}); // true if TCP is enabled on any rotary axis

  // save multi-axis feedrate settings from machine configuration
  var mode = machineConfiguration.getMultiAxisFeedrateMode();
  var type = mode == FEED_INVERSE_TIME ? machineConfiguration.getMultiAxisFeedrateInverseTimeUnits() :
    (mode == FEED_DPM ? machineConfiguration.getMultiAxisFeedrateDPMType() : DPM_STANDARD);
  multiAxisFeedrate = {
    mode     : mode,
    maximum  : machineConfiguration.getMultiAxisFeedrateMaximum(),
    type     : type,
    tolerance: mode == FEED_DPM ? machineConfiguration.getMultiAxisFeedrateOutputTolerance() : 0,
    bpwRatio : mode == FEED_DPM ? machineConfiguration.getMultiAxisFeedrateBpwRatio() : 1
  };

  // setup of retract/reconfigure  TAG: Only needed until post kernel supports these machine config settings
  if (receivedMachineConfiguration && machineConfiguration.performRewinds()) {
    safeRetractDistance = machineConfiguration.getSafeRetractDistance();
    safePlungeFeed = machineConfiguration.getSafePlungeFeedrate();
    safeRetractFeed = machineConfiguration.getSafeRetractFeedrate();
  }
  if (typeof safeRetractDistance == "number" && getProperty("safeRetractDistance") != undefined && getProperty("safeRetractDistance") != 0) {
    safeRetractDistance = getProperty("safeRetractDistance");
  }

  if (machineConfiguration.isHeadConfiguration()) {
    compensateToolLength = typeof compensateToolLength == "undefined" ? false : compensateToolLength;
  }

  if (machineConfiguration.isHeadConfiguration() && compensateToolLength) {
    for (var i = 0; i < getNumberOfSections(); ++i) {
      var section = getSection(i);
      if (section.isMultiAxis()) {
        machineConfiguration.setToolLength(getBodyLength(section.getTool())); // define the tool length for head adjustments
        section.optimizeMachineAnglesByMachine(machineConfiguration, OPTIMIZE_AXIS);
      }
    }
  } else {
    optimizeMachineAngles2(OPTIMIZE_AXIS);
  }
}

function getBodyLength(tool) {
  for (var i = 0; i < getNumberOfSections(); ++i) {
    var section = getSection(i);
    if (tool.number == section.getTool().number) {
      return section.getParameter("operation:tool_overallLength", tool.bodyLength + tool.holderLength);
    }
  }
  return tool.bodyLength + tool.holderLength;
}

function getFeed(f) {
  if (getProperty("useG95")) {
    return feedOutput.format(f / spindleSpeed); // use feed value
  }
  if (typeof activeMovements != "undefined" && activeMovements) {
    var feedContext = activeMovements[movement];
    if (feedContext != undefined) {
      if (!feedFormat.areDifferent(feedContext.feed, f)) {
        if (feedContext.id == currentFeedId) {
          return ""; // nothing has changed
        }
        forceFeed();
        currentFeedId = feedContext.id;
        return settings.parametricFeeds.feedOutputVariable + (settings.parametricFeeds.firstFeedParameter + feedContext.id);
      }
    }
    currentFeedId = undefined; // force parametric feed next time
  }
  return feedOutput.format(f); // use feed value
}

function validateCommonParameters() {
  validateToolData();
  for (var i = 0; i < getNumberOfSections(); ++i) {
    var section = getSection(i);
    if (getSection(0).workOffset == 0 && section.workOffset > 0) {
      error(localize("Using multiple work offsets is not possible if the initial work offset is 0."));
    }
    if (section.isMultiAxis()) {
      if (!section.isOptimizedForMachine() && !getSetting("supportsToolVectorOutput", false)) {
        error(localize("This postprocessor requires a machine configuration for 5-axis simultaneous toolpath."));
      }
      if (machineConfiguration.getMultiAxisFeedrateMode() == FEED_INVERSE_TIME && !getSetting("supportsInverseTimeFeed", true)) {
        error(localize("This postprocessor does not support inverse time feedrates."));
      }
    }
  }
  if (!tcp.isSupportedByControl && tcp.isSupportedByMachine) {
    error(localize("The machine configuration has TCP enabled which is not supported by this postprocessor."));
  }
  if (getProperty("safePositionMethod") == "clearanceHeight") {
    var msg = "-Attention- Property 'Safe Retracts' is set to 'Clearance Height'." + EOL +
      "Ensure the clearance height will clear the part and or fixtures." + EOL +
      "Raise the Z-axis to a safe height before starting the program.";
    warning(msg);
    writeComment(msg);
  }
}

function validateToolData() {
  var _default = 99999;
  var _maximumSpindleRPM = machineConfiguration.getMaximumSpindleSpeed() > 0 ? machineConfiguration.getMaximumSpindleSpeed() :
    settings.maximumSpindleRPM == undefined ? _default : settings.maximumSpindleRPM;
  var _maximumToolNumber = machineConfiguration.isReceived() && machineConfiguration.getNumberOfTools() > 0 ? machineConfiguration.getNumberOfTools() :
    settings.maximumToolNumber == undefined ? _default : settings.maximumToolNumber;
  var _maximumToolLengthOffset = settings.maximumToolLengthOffset == undefined ? _default : settings.maximumToolLengthOffset;
  var _maximumToolDiameterOffset = settings.maximumToolDiameterOffset == undefined ? _default : settings.maximumToolDiameterOffset;

  var header = ["Detected maximum values are out of range.", "Maximum values:"];
  var warnings = {
    toolNumber    : {msg:"Tool number value exceeds the maximum value for tool: " + EOL, max:" Tool number: " + _maximumToolNumber, values:[]},
    lengthOffset  : {msg:"Tool length offset value exceeds the maximum value for tool: " + EOL, max:" Tool length offset: " + _maximumToolLengthOffset, values:[]},
    diameterOffset: {msg:"Tool diameter offset value exceeds the maximum value for tool: " + EOL, max:" Tool diameter offset: " + _maximumToolDiameterOffset, values:[]},
    spindleSpeed  : {msg:"Spindle speed exceeds the maximum value for operation: " + EOL, max:" Spindle speed: " + _maximumSpindleRPM, values:[]}
  };

  var toolIds = [];
  for (var i = 0; i < getNumberOfSections(); ++i) {
    var section = getSection(i);
    if (toolIds.indexOf(section.getTool().getToolId()) === -1) { // loops only through sections which have a different tool ID
      var toolNumber = section.getTool().number;
      var lengthOffset = section.getTool().lengthOffset;
      var diameterOffset = section.getTool().diameterOffset;
      var comment = section.getParameter("operation-comment", "");

      if (toolNumber > _maximumToolNumber && !getProperty("toolAsName")) {
        warnings.toolNumber.values.push(SP + toolNumber + EOL);
      }
      if (lengthOffset > _maximumToolLengthOffset) {
        warnings.lengthOffset.values.push(SP + "Tool " + toolNumber + " (" + comment + "," + " Length offset: " + lengthOffset + ")" + EOL);
      }
      if (diameterOffset > _maximumToolDiameterOffset) {
        warnings.diameterOffset.values.push(SP + "Tool " + toolNumber + " (" + comment + "," + " Diameter offset: " + diameterOffset + ")" + EOL);
      }
      toolIds.push(section.getTool().getToolId());
    }
    // loop through all sections regardless of tool id for idenitfying spindle speeds

    // identify if movement ramp is used in current toolpath, use ramp spindle speed for comparisons
    var ramp = section.getMovements() & ((1 << MOVEMENT_RAMP) | (1 << MOVEMENT_RAMP_ZIG_ZAG) | (1 << MOVEMENT_RAMP_PROFILE) | (1 << MOVEMENT_RAMP_HELIX));
    var _sectionSpindleSpeed = Math.max(section.getTool().spindleRPM, ramp ? section.getTool().rampingSpindleRPM : 0, 0);
    if (_sectionSpindleSpeed > _maximumSpindleRPM) {
      warnings.spindleSpeed.values.push(SP + section.getParameter("operation-comment", "") + " (" + _sectionSpindleSpeed + " RPM" + ")" + EOL);
    }
  }

  // sort lists by tool number
  warnings.toolNumber.values.sort(function(a, b) {return a - b;});
  warnings.lengthOffset.values.sort(function(a, b) {return a.localeCompare(b);});
  warnings.diameterOffset.values.sort(function(a, b) {return a.localeCompare(b);});

  var warningMessages = [];
  for (var key in warnings) {
    if (warnings[key].values != "") {
      header.push(warnings[key].max); // add affected max values to the header
      warningMessages.push(warnings[key].msg + warnings[key].values.join(""));
    }
  }
  if (warningMessages.length != 0) {
    warningMessages.unshift(header.join(EOL) + EOL);
    warning(warningMessages.join(EOL));
  }
}

function forceFeed() {
  currentFeedId = undefined;
  feedOutput.reset();
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of A, B, and C. */
function forceABC() {
  aOutput.reset();
  bOutput.reset();
  cOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  forceABC();
  forceFeed();
}

/**
  Writes the specified block.
*/
function writeBlock() {
  var text = formatWords(arguments);
  if (!text) {
    return;
  }
  var prefix = getSetting("sequenceNumberPrefix", "N");
  var suffix = getSetting("writeBlockSuffix", "");
  if ((optionalSection || skipBlocks) && !getSetting("supportsOptionalBlocks", true)) {
    error(localize("Optional blocks are not supported by this post."));
  }
  if (getProperty("showSequenceNumbers") == "true") {
    if (sequenceNumber == undefined || sequenceNumber >= settings.maximumSequenceNumber) {
      sequenceNumber = getProperty("sequenceNumberStart");
    }
    if (optionalSection || skipBlocks) {
      writeWords2("/", prefix + sequenceNumber, text + suffix);
    } else {
      writeWords2(prefix + sequenceNumber, text + suffix);
    }
    sequenceNumber += getProperty("sequenceNumberIncrement");
  } else {
    if (optionalSection || skipBlocks) {
      writeWords2("/", text + suffix);
    } else {
      writeWords(text + suffix);
    }
  }
}

validate(settings.comments, "Setting 'comments' is required but not defined.");
function formatComment(text) {
  var prefix = settings.comments.prefix;
  var suffix = settings.comments.suffix;
  var _permittedCommentChars = settings.comments.permittedCommentChars == undefined ? "" : settings.comments.permittedCommentChars;
  switch (settings.comments.outputFormat) {
  case "upperCase":
    text = text.toUpperCase();
    _permittedCommentChars = _permittedCommentChars.toUpperCase();
    break;
  case "lowerCase":
    text = text.toLowerCase();
    _permittedCommentChars = _permittedCommentChars.toLowerCase();
    break;
  case "ignoreCase":
    _permittedCommentChars = _permittedCommentChars.toUpperCase() + _permittedCommentChars.toLowerCase();
    break;
  default:
    error(localize("Unsupported option specified for setting 'comments.outputFormat'."));
  }
  if (_permittedCommentChars != "") {
    text = filterText(String(text), _permittedCommentChars);
  }
  text = String(text).substring(0, settings.comments.maximumLineLength - prefix.length - suffix.length);
  return text != "" ?  prefix + text + suffix : "";
}

/**
  Output a comment.
*/
function writeComment(text) {
  if (!text) {
    return;
  }
  var comments = String(text).split(EOL);
  for (comment in comments) {
    var _comment = formatComment(comments[comment]);
    if (_comment) {
      if (getSetting("comments.showSequenceNumbers", false)) {
        writeBlock(_comment);
      } else {
        writeln(_comment);
      }
    }
  }
}

function onComment(text) {
  writeComment(text);
}

/**
  Writes the specified block - used for tool changes only.
*/
function writeToolBlock() {
  var show = getProperty("showSequenceNumbers");
  setProperty("showSequenceNumbers", (show == "true" || show == "toolChange") ? "true" : "false");
  writeBlock(arguments);
  setProperty("showSequenceNumbers", show);
}

var skipBlocks = false;
var initialState = JSON.parse(JSON.stringify(state)); // save initial state
var optionalState = JSON.parse(JSON.stringify(state));
var saveCurrentSectionId = undefined;
function writeStartBlocks(isRequired, code) {
  var saveSkipBlocks = skipBlocks;
  var saveMainState = state; // save main state

  if (!isRequired) {
    if (!getProperty("safeStartAllOperations", false)) {
      return; // when safeStartAllOperations is disabled, dont output code and return
    }
    if (saveCurrentSectionId != getCurrentSectionId()) {
      saveCurrentSectionId = getCurrentSectionId();
      forceModals(); // force all modal variables when entering a new section
      optionalState = Object.create(initialState); // reset optionalState to initialState when entering a new section
    }
    skipBlocks = true; // if values are not required, but safeStartAllOperations is enabled - write following blocks as optional
    state = optionalState; // set state to optionalState if skipBlocks is true
    state.mainState = false;
  }
  code(); // writes out the code which is passed to this function as an argument

  state = saveMainState; // restore main state
  skipBlocks = saveSkipBlocks; // restore skipBlocks value
}

var pendingRadiusCompensation = -1;
function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
  if (pendingRadiusCompensation >= 0 && !getSetting("supportsRadiusCompensation", true)) {
    error(localize("Radius compensation mode is not supported."));
    return;
  }
}

function onPassThrough(text) {
  var commands = String(text).split(",");
  for (text in commands) {
    writeBlock(commands[text]);
  }
}

function forceModals() {
  if (arguments.length == 0) { // reset all modal variables listed below
    if (typeof gMotionModal != "undefined") {
      gMotionModal.reset();
    }
    if (typeof gPlaneModal != "undefined") {
      gPlaneModal.reset();
    }
    if (typeof gAbsIncModal != "undefined") {
      gAbsIncModal.reset();
    }
    if (typeof gFeedModeModal != "undefined") {
      gFeedModeModal.reset();
    }
  } else {
    for (var i in arguments) {
      arguments[i].reset(); // only reset the modal variable passed to this function
    }
  }
}

/** Helper function to be able to use a default value for settings which do not exist. */
function getSetting(setting, defaultValue) {
  var result = defaultValue;
  var keys = setting.split(".");
  var obj = settings;
  for (var i in keys) {
    if (obj[keys[i]] != undefined) { // setting does exist
      result = obj[keys[i]];
      if (typeof [keys[i]] === "object") {
        obj = obj[keys[i]];
        continue;
      }
    } else { // setting does not exist, use default value
      if (defaultValue != undefined) {
        result = defaultValue;
      } else {
        error("Setting '" + keys[i] + "' has no default value and/or does not exist.");
        return undefined;
      }
    }
  }
  return result;
}

function getForwardDirection(_section) {
  var forward = undefined;
  var _optimizeType = settings.workPlaneMethod && settings.workPlaneMethod.optimizeType;
  if (_section.isMultiAxis()) {
    forward = _section.workPlane.forward;
  } else if (!getSetting("workPlaneMethod.useTiltedWorkplane", false) && machineConfiguration.isMultiAxisConfiguration()) {
    if (_optimizeType == undefined) {
      var saveRotation = getRotation();
      getWorkPlaneMachineABC(_section, true);
      forward = getRotation().forward;
      setRotation(saveRotation); // reset rotation
    } else {
      var abc = getWorkPlaneMachineABC(_section, false);
      var forceAdjustment = settings.workPlaneMethod.optimizeType == OPTIMIZE_TABLES || settings.workPlaneMethod.optimizeType == OPTIMIZE_BOTH;
      forward = machineConfiguration.getOptimizedDirection(_section.workPlane.forward, abc, false, forceAdjustment);
    }
  } else {
    forward = getRotation().forward;
  }
  return forward;
}

function getRetractParameters() {
  var _arguments = typeof arguments[0] === "object" ? arguments[0].axes : arguments;
  var singleLine = arguments[0].singleLine == undefined ? true : arguments[0].singleLine;
  var words = []; // store all retracted axes in an array
  var retractAxes = new Array(false, false, false);
  var method = getProperty("safePositionMethod", "undefined");
  if (method == "clearanceHeight") {
    if (!is3D()) {
      error(localize("Safe retract option 'Clearance Height' is only supported when all operations are along the setup Z-axis."));
    }
    return undefined;
  }
  validate(settings.retract, "Setting 'retract' is required but not defined.");
  validate(_arguments.length != 0, "No axis specified for getRetractParameters().");
  for (i in _arguments) {
    retractAxes[_arguments[i]] = true;
  }
  if ((retractAxes[0] || retractAxes[1]) && !state.retractedZ) { // retract Z first before moving to X/Y home
    error(localize("Retracting in X/Y is not possible without being retracted in Z."));
    return undefined;
  }
  // special conditions
  if (retractAxes[0] || retractAxes[1]) {
    method = getSetting("retract.methodXY", method);
  }
  if (retractAxes[2]) {
    method = getSetting("retract.methodZ", method);
  }
  // define home positions
  var useZeroValues = (settings.retract.useZeroValues && settings.retract.useZeroValues.indexOf(method) != -1);
  var _xHome = machineConfiguration.hasHomePositionX() && !useZeroValues ? machineConfiguration.getHomePositionX() : toPreciseUnit(0, MM);
  var _yHome = machineConfiguration.hasHomePositionY() && !useZeroValues ? machineConfiguration.getHomePositionY() : toPreciseUnit(0, MM);
  var _zHome = machineConfiguration.getRetractPlane() != 0 && !useZeroValues ? machineConfiguration.getRetractPlane() : toPreciseUnit(0, MM);
  for (var i = 0; i < _arguments.length; ++i) {
    switch (_arguments[i]) {
    case X:
      if (!state.retractedX) {
        words.push("X" + xyzFormat.format(_xHome));
        xOutput.reset();
        state.retractedX = true;
      }
      break;
    case Y:
      if (!state.retractedY) {
        words.push("Y" + xyzFormat.format(_yHome));
        yOutput.reset();
        state.retractedY = true;
      }
      break;
    case Z:
      if (!state.retractedZ) {
        words.push("Z" + xyzFormat.format(_zHome));
        zOutput.reset();
        state.retractedZ = true;
      }
      break;
    default:
      error(localize("Unsupported axis specified for getRetractParameters()."));
      return undefined;
    }
  }
  return {method:method, retractAxes:retractAxes, words:words, singleLine:singleLine};
}

/** Returns true when subprogram logic does exist into the post. */
function subprogramsAreSupported() {
  return typeof subprogramState != "undefined";
}
// <<<<< INCLUDED FROM include_files/commonFunctions.cpi
// >>>>> INCLUDED FROM include_files/defineMachine.cpi
var compensateToolLength = false; // add the tool length to the pivot distance for nonTCP rotary heads
function defineMachine() {
  var useTCP = true;
  if (false) { // note: setup your machine here
    var aAxis = createAxis({coordinate:0, table:true, axis:[1, 0, 0], range:[-120, 120], preference:1, tcp:useTCP});
    var cAxis = createAxis({coordinate:2, table:true, axis:[0, 0, 1], range:[-360, 360], preference:0, tcp:useTCP});
    machineConfiguration = new MachineConfiguration(aAxis, cAxis);

    setMachineConfiguration(machineConfiguration);
    if (receivedMachineConfiguration) {
      warning(localize("The provided CAM machine configuration is overwritten by the postprocessor."));
      receivedMachineConfiguration = false; // CAM provided machine configuration is overwritten
    }
  }

  if (!receivedMachineConfiguration) {
    // multiaxis settings
    if (machineConfiguration.isHeadConfiguration()) {
      machineConfiguration.setVirtualTooltip(false); // translate the pivot point to the virtual tool tip for nonTCP rotary heads
    }

    // retract / reconfigure
    var performRewinds = false; // set to true to enable the rewind/reconfigure logic
    if (performRewinds) {
      machineConfiguration.enableMachineRewinds(); // enables the retract/reconfigure logic
      safeRetractDistance = (unit == IN) ? 1 : 25; // additional distance to retract out of stock, can be overridden with a property
      safeRetractFeed = (unit == IN) ? 20 : 500; // retract feed rate
      safePlungeFeed = (unit == IN) ? 10 : 250; // plunge feed rate
      machineConfiguration.setSafeRetractDistance(safeRetractDistance);
      machineConfiguration.setSafeRetractFeedrate(safeRetractFeed);
      machineConfiguration.setSafePlungeFeedrate(safePlungeFeed);
      var stockExpansion = new Vector(toPreciseUnit(0.1, IN), toPreciseUnit(0.1, IN), toPreciseUnit(0.1, IN)); // expand stock XYZ values
      machineConfiguration.setRewindStockExpansion(stockExpansion);
    }

    // multi-axis feedrates
    if (machineConfiguration.isMultiAxisConfiguration()) {
      machineConfiguration.setMultiAxisFeedrate(
        useTCP ? FEED_FPM : getProperty("useDPMFeeds") ? FEED_DPM : FEED_INVERSE_TIME,
        9999.99, // maximum output value for inverse time feed rates
        getProperty("useDPMFeeds") ? DPM_COMBINATION : INVERSE_MINUTES, // INVERSE_MINUTES/INVERSE_SECONDS or DPM_COMBINATION/DPM_STANDARD
        0.5, // tolerance to determine when the DPM feed has changed
        1.0 // ratio of rotary accuracy to linear accuracy for DPM calculations
      );
      setMachineConfiguration(machineConfiguration);
    }

    /* home positions */
    // machineConfiguration.setHomePositionX(toPreciseUnit(0, IN));
    // machineConfiguration.setHomePositionY(toPreciseUnit(0, IN));
    // machineConfiguration.setRetractPlane(toPreciseUnit(0, IN));
  }
}
// <<<<< INCLUDED FROM include_files/defineMachine.cpi
// >>>>> INCLUDED FROM include_files/defineWorkPlane.cpi
validate(settings.workPlaneMethod, "Setting 'workPlaneMethod' is required but not defined.");
function defineWorkPlane(_section, _setWorkPlane) {
  var abc = new Vector(0, 0, 0);
  if (settings.workPlaneMethod.forceMultiAxisIndexing || !is3D() || machineConfiguration.isMultiAxisConfiguration()) {
    if (isPolarModeActive()) {
      abc = getCurrentDirection();
    } else if (_section.isMultiAxis()) {
      forceWorkPlane();
      cancelTransformation();
      abc = _section.isOptimizedForMachine() ? _section.getInitialToolAxisABC() : _section.getGlobalInitialToolAxis();
    } else if (settings.workPlaneMethod.useTiltedWorkplane && settings.workPlaneMethod.eulerConvention != undefined) {
      if (settings.workPlaneMethod.eulerCalculationMethod == "machine" && machineConfiguration.isMultiAxisConfiguration()) {
        abc = machineConfiguration.getOrientation(getWorkPlaneMachineABC(_section, true)).getEuler2(settings.workPlaneMethod.eulerConvention);
      } else {
        abc = _section.workPlane.getEuler2(settings.workPlaneMethod.eulerConvention);
      }
    } else {
      abc = getWorkPlaneMachineABC(_section, true);
    }

    if (_setWorkPlane) {
      if (_section.isMultiAxis() || isPolarModeActive()) { // 4-5x simultaneous operations
        cancelWorkPlane();
        positionABC(abc, true);
      } else { // 3x and/or 3+2x operations
        setWorkPlane(abc);
      }
    }
  } else {
    var remaining = _section.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return abc;
    }
    setRotation(remaining);
  }
  tcp.isSupportedByOperation = isTCPSupportedByOperation(_section);
  return abc;
}

function isTCPSupportedByOperation(_section) {
  var _tcp = _section.getOptimizedTCPMode() == OPTIMIZE_NONE;
  if (!_section.isMultiAxis() && (settings.workPlaneMethod.useTiltedWorkplane ||
    isSameDirection(machineConfiguration.getSpindleAxis(), getForwardDirection(_section)) ||
    settings.workPlaneMethod.optimizeType == OPTIMIZE_HEADS ||
    settings.workPlaneMethod.optimizeType == OPTIMIZE_TABLES ||
    settings.workPlaneMethod.optimizeType == OPTIMIZE_BOTH)) {
    _tcp = false;
  }
  return _tcp;
}
// <<<<< INCLUDED FROM include_files/defineWorkPlane.cpi
// >>>>> INCLUDED FROM include_files/getWorkPlaneMachineABC.cpi
validate(settings.machineAngles, "Setting 'machineAngles' is required but not defined.");
function getWorkPlaneMachineABC(_section, rotate) {
  var currentABC = isFirstSection() ? new Vector(0, 0, 0) : getCurrentABC();
  var abc = machineConfiguration.getABCByPreference(_section.workPlane, currentABC, settings.machineAngles.controllingAxis, settings.machineAngles.type, settings.machineAngles.options);
  if (!isSameDirection(machineConfiguration.getDirection(abc), _section.workPlane.forward)) {
    error(localize("Orientation not supported."));
  }
  if (rotate) {
    if (settings.workPlaneMethod.optimizeType == undefined || settings.workPlaneMethod.useTiltedWorkplane) { // legacy
      var useTCP = false;
      var R = machineConfiguration.getRemainingOrientation(abc, _section.workPlane);
      setRotation(useTCP ? _section.workPlane : R);
    } else {
      if (!_section.isOptimizedForMachine()) {
        machineConfiguration.setToolLength(compensateToolLength ? _section.getTool().overallLength : 0); // define the tool length for head adjustments
        _section.optimize3DPositionsByMachine(machineConfiguration, abc, settings.workPlaneMethod.optimizeType);
      }
    }
  }
  return abc;
}
// <<<<< INCLUDED FROM include_files/getWorkPlaneMachineABC.cpi
// >>>>> INCLUDED FROM include_files/positionABC.cpi
function positionABC(abc, force) {
  if (typeof unwindABC == "function") {
    unwindABC(abc);
  }
  if (force) {
    forceABC();
  }
  var a = machineConfiguration.isMultiAxisConfiguration() ? aOutput.format(abc.x) : toolVectorOutputI.format(abc.x);
  var b = machineConfiguration.isMultiAxisConfiguration() ? bOutput.format(abc.y) : toolVectorOutputJ.format(abc.y);
  var c = machineConfiguration.isMultiAxisConfiguration() ? cOutput.format(abc.z) : toolVectorOutputK.format(abc.z);
  if (a || b || c) {
    writeRetract(Z);
    if (getSetting("retract.homeXY.onIndexing", false)) {
      writeRetract(settings.retract.homeXY.onIndexing);
    }
    onCommand(COMMAND_UNLOCK_MULTI_AXIS);
    gMotionModal.reset();
    writeBlock(gMotionModal.format(0), a, b, c);

    if (getCurrentSectionId() != -1) {
      setCurrentABC(abc); // required for machine simulation
    }
  }
}
// <<<<< INCLUDED FROM include_files/positionABC.cpi
// >>>>> INCLUDED FROM include_files/writeWCS.cpi
function writeWCS(section, wcsIsRequired) {
  if (section.workOffset != currentWorkOffset) {
    if (getSetting("workPlaneMethod.cancelTiltFirst", false) && wcsIsRequired) {
      cancelWorkPlane();
    }
    if (typeof forceWorkPlane == "function" && wcsIsRequired) {
      forceWorkPlane();
    }
    writeStartBlocks(wcsIsRequired, function () {
      writeBlock(section.wcs);
    });
    currentWorkOffset = section.workOffset;
  }
}
// <<<<< INCLUDED FROM include_files/writeWCS.cpi
// >>>>> INCLUDED FROM include_files/writeToolCall.cpi
function writeToolCall(tool, insertToolCall) {
  if (!isFirstSection()) {
    writeStartBlocks(!getProperty("safeStartAllOperations") && insertToolCall, function () {
      writeRetract(Z); // write optional Z retract before tool change if safeStartAllOperations is enabled
    });
  }
  writeStartBlocks(insertToolCall, function () {
    writeRetract(Z);
    if (getSetting("retract.homeXY.onToolChange", false)) {
      writeRetract(settings.retract.homeXY.onToolChange);
    }
    if (!isFirstSection() && insertToolCall) {
      if (typeof forceWorkPlane == "function") {
        forceWorkPlane();
      }
      onCommand(COMMAND_COOLANT_OFF); // turn off coolant on tool change
      if (typeof disableLengthCompensation == "function") {
        disableLengthCompensation(false);
      }
    }

    if (tool.manualToolChange) {
      onCommand(COMMAND_STOP);
      writeComment("MANUAL TOOL CHANGE TO T" + toolFormat.format(tool.number));
    } else {
      if (!isFirstSection() && getProperty("optionalStop") && insertToolCall) {
        onCommand(COMMAND_OPTIONAL_STOP);
      }
      onCommand(COMMAND_LOAD_TOOL);
    }
  });
  if (typeof forceModals == "function" && (insertToolCall || getProperty("safeStartAllOperations"))) {
    forceModals();
  }
}
// <<<<< INCLUDED FROM include_files/writeToolCall.cpi
// >>>>> INCLUDED FROM include_files/writeProgramHeader.cpi
properties.writeMachine = {
  title      : "Write machine",
  description: "Output the machine settings in the header of the program.",
  group      : "formats",
  type       : "boolean",
  value      : true,
  scope      : "post"
};
properties.writeTools = {
  title      : "Write tool list",
  description: "Output a tool list in the header of the program.",
  group      : "formats",
  type       : "boolean",
  value      : true,
  scope      : "post"
};
function writeProgramHeader() {
  // dump machine configuration
  var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
  var mDescription = machineConfiguration.getDescription();
  if (getProperty("writeMachine") && (vendor || model || mDescription)) {
    writeComment(localize("Machine"));
    if (vendor) {
      writeComment("  " + localize("vendor") + ": " + vendor);
    }
    if (model) {
      writeComment("  " + localize("model") + ": " + model);
    }
    if (mDescription) {
      writeComment("  " + localize("description") + ": "  + mDescription);
    }
  }

  // dump tool information
  if (getProperty("writeTools")) {
    if (false) { // set to true to use the post kernel version of the tool list
      writeToolTable(TOOL_NUMBER_COL);
    } else {
      var zRanges = {};
      if (is3D()) {
        var numberOfSections = getNumberOfSections();
        for (var i = 0; i < numberOfSections; ++i) {
          var section = getSection(i);
          var zRange = section.getGlobalZRange();
          var tool = section.getTool();
          if (zRanges[tool.number]) {
            zRanges[tool.number].expandToRange(zRange);
          } else {
            zRanges[tool.number] = zRange;
          }
        }
      }
      var tools = getToolTable();
      if (tools.getNumberOfTools() > 0) {
        for (var i = 0; i < tools.getNumberOfTools(); ++i) {
          var tool = tools.getTool(i);
          var comment = (getProperty("toolAsName") ? "\"" + tool.description.toUpperCase() + "\"" : "T" + toolFormat.format(tool.number)) + " " +
          "D=" + xyzFormat.format(tool.diameter) + " " +
          localize("CR") + "=" + xyzFormat.format(tool.cornerRadius);
          if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
            comment += " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg");
          }
          if (zRanges[tool.number]) {
            comment += " - " + localize("ZMIN") + "=" + xyzFormat.format(zRanges[tool.number].getMinimum());
          }
          comment += " - " + getToolTypeName(tool.type);
          writeComment(comment);
        }
      }
    }
  }
}
// <<<<< INCLUDED FROM include_files/writeProgramHeader.cpi

// >>>>> INCLUDED FROM include_files/onRapid_fanuc.cpi
function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
      return;
    }
    writeBlock(gMotionModal.format(0), x, y, z);
    forceFeed();
  }
}
// <<<<< INCLUDED FROM include_files/onRapid_fanuc.cpi
// >>>>> INCLUDED FROM include_files/onLinear_fanuc.cpi
function onLinear(_x, _y, _z, feed) {
  if (pendingRadiusCompensation >= 0) {
    xOutput.reset();
    yOutput.reset();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = getFeed(feed);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      var d = getSetting("outputToolDiameterOffset", true) ? diameterOffsetFormat.format(tool.diameterOffset) : "";
      writeBlock(gPlaneModal.format(17));
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(gMotionModal.format(1), gFormat.format(41), x, y, z, d, f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(gMotionModal.format(1), gFormat.format(42), x, y, z, d, f);
        break;
      default:
        writeBlock(gMotionModal.format(1), gFormat.format(40), x, y, z, f);
      }
    } else {
      writeBlock(gMotionModal.format(1), x, y, z, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}
// <<<<< INCLUDED FROM include_files/onLinear_fanuc.cpi
// >>>>> INCLUDED FROM include_files/onRapid5D_fanuc.cpi
function onRapid5D(_x, _y, _z, _a, _b, _c) {
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    return;
  }
  if (!currentSection.isOptimizedForMachine()) {
    forceXYZ();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = currentSection.isOptimizedForMachine() ? aOutput.format(_a) : toolVectorOutputI.format(_a);
  var b = currentSection.isOptimizedForMachine() ? bOutput.format(_b) : toolVectorOutputJ.format(_b);
  var c = currentSection.isOptimizedForMachine() ? cOutput.format(_c) : toolVectorOutputK.format(_c);

  if (x || y || z || a || b || c) {
    writeBlock(gMotionModal.format(0), x, y, z, a, b, c);
    forceFeed();
  }
}
// <<<<< INCLUDED FROM include_files/onRapid5D_fanuc.cpi
// >>>>> INCLUDED FROM include_files/onLinear5D_fanuc.cpi
function onLinear5D(_x, _y, _z, _a, _b, _c, feed, feedMode) {
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for 5-axis move."));
    return;
  }
  if (!currentSection.isOptimizedForMachine()) {
    forceXYZ();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = currentSection.isOptimizedForMachine() ? aOutput.format(_a) : toolVectorOutputI.format(_a);
  var b = currentSection.isOptimizedForMachine() ? bOutput.format(_b) : toolVectorOutputJ.format(_b);
  var c = currentSection.isOptimizedForMachine() ? cOutput.format(_c) : toolVectorOutputK.format(_c);
  if (feedMode == FEED_INVERSE_TIME) {
    forceFeed();
  }
  var f = feedMode == FEED_INVERSE_TIME ? inverseTimeOutput.format(feed) : getFeed(feed);
  var fMode = feedMode == FEED_INVERSE_TIME ? 93 : getProperty("useG95") ? 95 : 94;

  if (x || y || z || a || b || c) {
    writeBlock(gFeedModeModal.format(fMode), gMotionModal.format(1), x, y, z, a, b, c, f);
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      writeBlock(gFeedModeModal.format(fMode), gMotionModal.format(1), f);
    }
  }
}
// <<<<< INCLUDED FROM include_files/onLinear5D_fanuc.cpi
// >>>>> INCLUDED FROM include_files/workPlaneFunctions_fanuc.cpi
var currentWorkPlaneABC = undefined;
function forceWorkPlane() {
  currentWorkPlaneABC = undefined;
}

function cancelWorkPlane(force) {
  if (typeof gRotationModal != "undefined") {
    if (force) {
      gRotationModal.reset();
    }
    writeBlock(gRotationModal.format(69)); // cancel frame
  }
  forceWorkPlane();
}

function setWorkPlane(abc) {
  if (!settings.workPlaneMethod.forceMultiAxisIndexing && is3D() && !machineConfiguration.isMultiAxisConfiguration()) {
    return; // ignore
  }
  var workplaneIsRequired = (currentWorkPlaneABC == undefined) ||
    abcFormat.areDifferent(abc.x, currentWorkPlaneABC.x) ||
    abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y) ||
    abcFormat.areDifferent(abc.z, currentWorkPlaneABC.z);

  writeStartBlocks(workplaneIsRequired, function () {
    writeRetract(Z);
    if (getSetting("retract.homeXY.onIndexing", false)) {
      writeRetract(settings.retract.homeXY.onIndexing);
    }
    if (currentSection.getId() > 0 && (isTCPSupportedByOperation(getSection(currentSection.getId() - 1) || tcp.isSupportedByOperation)) && typeof disableLengthCompensation == "function") {
      disableLengthCompensation(); // cancel TCP
    }

    if (settings.workPlaneMethod.useTiltedWorkplane) {
      onCommand(COMMAND_UNLOCK_MULTI_AXIS);
      cancelWorkPlane();
      if (machineConfiguration.isMultiAxisConfiguration()) {
        var machineABC = abc.isNonZero() ? (currentSection.isMultiAxis() ? getCurrentDirection() : getWorkPlaneMachineABC(currentSection, false)) : abc;
        if (settings.workPlaneMethod.useABCPrepositioning || machineABC.isZero()) {
          positionABC(machineABC, false);
        } else {
          setCurrentABC(machineABC);
        }
      }
      if (abc.isNonZero() || !machineConfiguration.isMultiAxisConfiguration()) {
        gRotationModal.reset();
        writeBlock(
          gRotationModal.format(68.2), "X" + xyzFormat.format(currentSection.workOrigin.x), "Y" + xyzFormat.format(currentSection.workOrigin.y), "Z" + xyzFormat.format(currentSection.workOrigin.z),
          "I" + abcFormat.format(abc.x), "J" + abcFormat.format(abc.y), "K" + abcFormat.format(abc.z)
        ); // set frame
        writeBlock(gFormat.format(53.1)); // turn machine
      }
    } else {
      positionABC(abc, true);
    }
    if (!currentSection.isMultiAxis()) {
      onCommand(COMMAND_LOCK_MULTI_AXIS);
    }
    currentWorkPlaneABC = abc;
  });
}
// <<<<< INCLUDED FROM include_files/workPlaneFunctions_fanuc.cpi
// >>>>> INCLUDED FROM include_files/initialPositioning_fanuc.cpi
/**
 * Writes the initial positioning procedure for a section to get to the start position of the toolpath.
 * @param {Vector} position The initial position to move to
 * @param {boolean} isRequired true: Output full positioning, false: Output full positioning in optional state or output simple positioning only
 * @param {String} codes1 Allows to add additional code to the first positioning line
 * @param {String} codes2 Allows to add additional code to the second positioning line (if applicable)
 * @example
  var myVar1 = formatWords("T" + tool.number, currentSection.wcs);
  var myVar2 = getCoolantCodes(tool.coolant);
  writeInitialPositioning(initialPosition, isRequired, myVar1, myVar2);
*/
function writeInitialPositioning(position, isRequired, codes1, codes2) {
  var motionCode = {single:0, multi:0};
  switch (highFeedMapping) {
  case HIGH_FEED_MAP_ANY:
    motionCode = {single:1, multi:1}; // map all rapid traversals to high feed
    break;
  case HIGH_FEED_MAP_MULTI:
    motionCode = {single:0, multi:1}; // map rapid traversal along more than one axis to high feed
    break;
  }
  var feed = (highFeedMapping != HIGH_FEED_NO_MAPPING) ? getFeed(highFeedrate) : "";
  var gOffset = getSetting("outputToolLengthCompensation", true) ? gFormat.format(getOffsetCode()) : "";
  var hOffset = getSetting("outputToolLengthOffset", true) ? hFormat.format(tool.lengthOffset) : "";
  var additionalCodes = [formatWords(codes1), formatWords(codes2)];

  forceModals(gMotionModal);
  writeStartBlocks(isRequired, function() {
    var modalCodes = formatWords(gAbsIncModal.format(90), gPlaneModal.format(17));
    if (typeof disableLengthCompensation == "function") {
      disableLengthCompensation(!isRequired); // cancel tool length compensation prior to enabling it, required when switching G43/G43.4 modes
    }

    // multi axis prepositioning with TWP
    if (currentSection.isMultiAxis() && getSetting("workPlaneMethod.prepositionWithTWP", true) && getSetting("workPlaneMethod.useTiltedWorkplane", false) &&
      tcp.isSupportedByOperation && getCurrentDirection().isNonZero()) {
      var W = machineConfiguration.isMultiAxisConfiguration() ? machineConfiguration.getOrientation(getCurrentDirection()) :
        Matrix.getOrientationFromDirection(getCurrentDirection());
      var prePosition = W.getTransposed().multiply(position);
      var angles = W.getEuler2(settings.workPlaneMethod.eulerConvention);
      setWorkPlane(angles);
      writeBlock(modalCodes, gMotionModal.format(motionCode.multi), xOutput.format(prePosition.x), yOutput.format(prePosition.y), feed, additionalCodes[0]);
      cancelWorkPlane();
      writeBlock(gOffset, hOffset, additionalCodes[1]); // omit Z-axis output is desired
      state.lengthCompensationActive = true;
      forceAny(); // required to output XYZ coordinates in the following line
    } else {
      if (machineConfiguration.isHeadConfiguration()) {
        writeBlock(modalCodes, gMotionModal.format(motionCode.multi), gOffset,
          xOutput.format(position.x), yOutput.format(position.y), zOutput.format(position.z),
          hOffset, feed, additionalCodes
        );
      } else {
        writeBlock(modalCodes, gMotionModal.format(motionCode.multi), xOutput.format(position.x), yOutput.format(position.y), feed, additionalCodes[0]);
        writeBlock(gMotionModal.format(motionCode.single), gOffset, zOutput.format(position.z), hOffset, additionalCodes[1]);
      }
      state.lengthCompensationActive = true;
    }
    forceModals(gMotionModal);
    if (isRequired) {
      additionalCodes = []; // clear additionalCodes buffer
    }
  });

  validate(!validateLengthCompensation || state.lengthCompensationActive, "Tool length compensation is not active."); // make sure that lenght compensation is enabled
  if (!isRequired) { // simple positioning
    var modalCodes = formatWords(gAbsIncModal.format(90), gPlaneModal.format(17));
    if (!state.retractedZ && xyzFormat.getResultingValue(getCurrentPosition().z) < xyzFormat.getResultingValue(position.z)) {
      writeBlock(modalCodes, gMotionModal.format(motionCode.single), zOutput.format(position.z), feed);
    }
    forceXYZ();
    writeBlock(modalCodes, gMotionModal.format(motionCode.multi), xOutput.format(position.x), yOutput.format(position.y), feed, additionalCodes);
  }
}

Matrix.getOrientationFromDirection = function (ijk) {
  var forward = ijk;
  var unitZ = new Vector(0, 0, 1);
  var W;
  if (Math.abs(Vector.dot(forward, unitZ)) < 0.5) {
    var imX = Vector.cross(forward, unitZ).getNormalized();
    W = new Matrix(imX, Vector.cross(forward, imX), forward);
  } else {
    var imX = Vector.cross(new Vector(0, 1, 0), forward).getNormalized();
    W = new Matrix(imX, Vector.cross(forward, imX), forward);
  }
  return W;
};
// <<<<< INCLUDED FROM include_files/initialPositioning_fanuc.cpi
