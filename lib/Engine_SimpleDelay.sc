Engine_SimpleDelay : CroneEngine {
  var <responder; 
  //var <onsetdetector;
  var synth;
  // var recorder;
  var buffer1;
  var buffer2;
  var bufnum1=12;
  var bufnum2=13;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc { 
    buffer1 = Buffer.alloc(context.server,48000 * 0.03, 1,bufnum:bufnum1); 
    buffer2 = Buffer.alloc(context.server,48000 * 0.03, 1,bufnum:bufnum2); 
    // synth = { arg delay=0.03, volume=0.0;
    //   var input = SoundIn.ar([0, 1]);
    //   BufDelayC.ar([bufnum1,bufnum2], input, delayTime:0.03, mul:volume)
    // }.play(context.server);

    synth = { arg threshold=(-60), volume=0.0;
      var input = Mix.new(SoundIn.ar([0, 1]));
      var onset = Trig.kr(Coyote.kr(input,fastLag:0.05,fastMul:0.9,thresh:threshold.dbamp,minDur:0.2));
      SendTrig.kr(onset,0,1);
      Silent.ar();
    }.play(context.server);

    // onset detection!
    // onsetdetector = { arg onset_threshold=0.1, onsets_delay = 0, volume=0;
    //   var input = SoundIn.ar([0, 1]);
    //   var chain = FFT(LocalBuf(512), input);
    //   var onsets = Onsets.kr(chain, onset_threshold, \rcomplex, floor: 0.02,mingap:20);
    //   SendTrig.kr(onsets, 0, 1);
    // }.play(context.server);
    responder = OSCFunc(
        { 
          arg msg, time; 
          // postln('['++time++']');
          NetAddr("127.0.0.1", 10111).sendMsg("onset",1,time); 
        },'/tr', context.server.addr);

    this.addCommand("threshold", "f", { arg msg; synth.set(\threshold, msg[1]);});
  }

  free {
    responder.free;
    // onsetdetector.free;
    synth.free;
    // recorder.free;
    buffer1.free;
    buffer2.free;
  }
} 
