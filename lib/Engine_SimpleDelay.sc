Engine_SimpleDelay : CroneEngine {
  var synth;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc { 
    synth = { arg delay=0.005;
      var input = SoundIn.ar([0, 1]);
      DelayC.ar(input, maxDelayTime:0.01, delayTime:delay)
    }.play(context.server);

    this.addCommand("delay", "f", { arg msg; synth.set(\delay, msg[1]); });
  }
}