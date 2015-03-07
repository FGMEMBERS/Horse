aircraft.livery.init("Aircraft/Horse/Models/Liveries");

# The 4th tank is not supported for the moment
setlistener("/sim/signals/fdm-initialized", func {
    setprop("/engines/engine[1]/rpm", 0);
    # fire up
    find_driving_aircraft();
    speed_control();
    animate_horse();
    ground_control();
    changeView(0);
});


# Change view to 
var changeView = func (n = 0){
  var actualView = props.globals.getNode("/sim/current-view/view-number", 1);
  if (actualView.getValue() == n){
    actualView.setValue(0);
  }else{
    actualView.setValue(n);
  }
}

# Change view if horse is swimming
 setlistener("/controls/special/swimming", func(swim) {
  	var actualView = props.globals.getNode("/sim/current-view/view-number", 1);
  	if(swim.getBoolValue()){ 
     if(actualView.getValue() == 0) actualView.setValue(8);
    }else{
     if(actualView.getValue() == 8) actualView.setValue(0);
    }
    
 }, 1, 0);

# going with keyboard 
var jump = func(){
    var swimming = getprop("/controls/special/swimming") or 0;
    var jump_from = getprop("/fdm/jsbsim/position/h-agl-ft") or 0;
    var alt_ft = getprop("position/altitude-ft") or 0;
    var new_alt_ft = alt_ft + 6.0;
    if (jump_from < 2.0){
      for(alt_ft; alt_ft < new_alt_ft; alt_ft += 0.002){
          setprop("position/altitude-ft", alt_ft);
      }
    }
}

var find_driving_aircraft = func() {

    var mp_craft = props.globals.getNode("/ai/models").getChildren("multiplayer");
    var ttl = size(mp_craft);
    var range = getprop("/instrumentation/radar/range");
    var h_offset = 0.0;

    #print(ttl ~" Flieger koennen treiben");
	
	var pushMe = getprop("/controls/special/push-me") or 0;
    
    for(var n = 0; n < ttl; n += 1) {
	    
        if (is_valid_driving_aircraft(mp_craft[n]) and pushMe) {
            # first get the nearest aircraft for heading setting
            # print (mp_craft[n].getNode("callsign").getValue());
            
            if(mp_craft[n].getNode("radar/range-nm").getValue() < range){
              range = mp_craft[n].getNode("radar/range-nm").getValue();
              # print(range~" | "~mp_craft[n].getNode("callsign").getValue() ~" ist Treiber");

              h_offset = mp_craft[n].getNode("radar/h-offset").getValue();

              # aircraft is comming from the left
              if(h_offset <= 0 and h_offset > -150){
                setprop("/controls/flight/rudder", 0.4);
                setprop("/controls/engines/engine/throttle", 1);
              }
              # aircraft is comming from the right
              if(h_offset > 0 and h_offset < 150){
                setprop("/controls/flight/rudder", -0.4);
                setprop("/controls/engines/engine/throttle", 1);
              }
              # if aircraft is behind the horse set rudder back
               if(h_offset < -150 or (h_offset > 150 and h_offset < 180)){
                setprop("/controls/flight/rudder", 0);
              }     

              setprop("/controls/gear/brake-parking", 0); 
            }else{
              # print("Wurde nicht beruecksichtigt");
            }
        }
        var is_rudder = getprop("/controls/flight/rudder");
        if(is_rudder == 0.4 or is_rudder == -0.4){ 
          interpolate("/controls/flight/rudder", 0, 1.0);
          # print("Ruder wurde zurueck gestellt");
        }
    }
    #setprop("/sim/crashed", 0);
    settimer(func { find_driving_aircraft(); }, 4);
}

############## Helper #####################

var is_valid_driving_aircraft = func(target) {
    if (target.getNode("sim/model/path").getValue() != "Aircraft/Horse/Models/Horse.xml"){
      return target.getNode("radar/in-range").getValue();
    }else{
      #print("Pferde treiben sich nicht gegenseitig...");
      return 0;
    }
}

var speed_control = func(){
  var speed = getprop("/velocities/groundspeed-kt") or 0;
  var pitch = getprop("/orientation/pitch-deg") or 0;
  var impact = getprop("/fdm/jsbsim/systems/crash-test/impact") or 0;
  var jump_agl = getprop("/fdm/jsbsim/position/h-agl-ft") or 0;
  var swimming = getprop("/controls/special/swimming") or 0;

  # speed limiter in case of pitch up or down (climb up a mountain or descent)
  if(speed > 40){
    setprop("/controls/gear/brake-left", 1);
    setprop("/controls/gear/brake-right", 1);
    setprop("/controls/gear/brake-parking", 1);
  }else if(speed > 30 and speed < 40){
    setprop("/controls/gear/brake-left", 1);
    setprop("/controls/gear/brake-right", 1);
    setprop("/controls/gear/brake-parking", 0);
  }else if(speed > 20 and pitch > 15 and pitch < 20){
    setprop("/controls/gear/brake-left", 1);
    setprop("/controls/gear/brake-right", 1);
  }else if(speed > 15 and pitch > 20 and pitch < 26){
    setprop("/controls/gear/brake-left", 1);
    setprop("/controls/gear/brake-right", 1);
  }else if(speed > 10 and pitch > 26){
    setprop("/controls/gear/brake-left", 1);
    setprop("/controls/gear/brake-right", 1);
  }else if(speed > 10 and swimming > 0){
    setprop("/controls/gear/brake-left", 1);
    setprop("/controls/gear/brake-right", 1);
  }else{
    setprop("/controls/gear/brake-left", 0);
    setprop("/controls/gear/brake-right", 0);
  }

  # gait control
  if (jump_agl >= 1.8) {
    setprop("/controls/gear/move-feets", 4.0);
  }else if (speed >= 15) {
    setprop("/controls/gear/move-feets", 3.0);
  }else if (speed >= 5) {
    setprop("/controls/gear/move-feets", 2.0);
  }else if (speed >= 0.1) {
    setprop("/controls/gear/move-feets", 1.0);
  }else{
    setprop("/controls/gear/move-feets", 0.0);
  }

  settimer(func { speed_control(); }, 0.125);
}

# ground control - swimming in water 
var ground_control = func {
  var lat = getprop("/position/latitude-deg");
  var lon = getprop("/position/longitude-deg");
  var swim = props.globals.getNode("/controls/special/swimming");

  var info = geodinfo(lat, lon);
  if (info != nil) {
    if (info[1] != nil and info[1].solid !=nil){
      #print(info[1].solid);
      if (!info[1].solid){
        swim.setBoolValue(1);
      }else{
        swim.setBoolValue(0);
      }
    }     
  }
  settimer(func { ground_control(); }, 0);
}

# for animate the head, body and feets moving
var animate_horse = func() {
  var angle = getprop("/engines/engine[1]/rpm") or 0;
  var gait = getprop("/controls/gear/move-feets") or 0;

  if(gait == 1){          # walk
    if(angle >= 1.6){
      setprop("/engines/engine[1]/rpm", 0);
    }else{
      setprop("/engines/engine[1]/rpm", getprop("/engines/engine[1]/rpm") + 0.1);
    }
    settimer(func { animate_horse(); }, 0.1);

  }else if(gait == 2){    # trot
    if(angle >= 1.8){
      setprop("/engines/engine[1]/rpm", 0);
    }else{
      setprop("/engines/engine[1]/rpm", getprop("/engines/engine[1]/rpm") + 0.1);
    }
    settimer(func { animate_horse(); }, 0.05);

  }else if(gait == 3){    # gallop
    if(angle >= 1.4){
      setprop("/engines/engine[1]/rpm", 0);
    }else{
      setprop("/engines/engine[1]/rpm", getprop("/engines/engine[1]/rpm") + 0.1);
    }
    settimer(func { animate_horse(); }, 0.05);

  }else if(gait == 4){    # jump
    if(angle >= 1.4){
      setprop("/engines/engine[1]/rpm", 1.4);
    }else{
      setprop("/engines/engine[1]/rpm", getprop("/engines/engine[1]/rpm") + 0.1);
    }
    settimer(func { animate_horse(); }, 0.0);

  }else{
    setprop("/engines/engine[1]/rpm", 0);
    settimer(func { animate_horse(); }, 0.5);
  }
}

