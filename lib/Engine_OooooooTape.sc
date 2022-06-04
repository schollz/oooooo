Engine_OoooooTape : CroneEngine {
  var responder; 
  var synth;
  // var recorder;
  var buffer1;
  var buffer2;
  var bufnum1=12;
  var bufnum2=13;

    // <Tape>
    var synTape;
    // </Tape>
    var fxbus;
    var fxsyn;


  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc { 
    fxbus=Dictionary.new();
    fxsyn=Dictionary.new();
    buffer1 = Buffer.alloc(context.server,48000 * 0.03, 1,bufnum:bufnum1); 
    buffer2 = Buffer.alloc(context.server,48000 * 0.03, 1,bufnum:bufnum2); 
    // synth = { arg delay=0.03, volume=0.0;
    //   var input = SoundIn.ar([0, 1]);
    //   BufDelayC.ar([bufnum1,bufnum2], input, delayTime:0.03, mul:volume)
    // }.play(context.server);

    synth = { arg threshold=(-60), volume=0.0;
      // var input = Mix.new(SoundIn.ar([0, 1]));
      // var onset = Trig.kr(Coyote.kr(input,fastLag:0.05,fastMul:0.9,thresh:threshold.dbamp,minDur:0.2));
      // SendTrig.kr(onset,0,1);
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



        SynthDef("defTape",{
            arg in, auxinBus,tape_wetBus,tape_biasBus,tape_satBus,tape_driveBus,
            tape_oversample=1,mode=0,
            dist_wetBus,dist_driveBus,dist_biasBus,dist_lowBus,dist_highBus,
            dist_shelfBus,dist_oversample=2,
            wowflu=1.0,
            wobble_rpm=33, wobble_amp=0.05, flutter_amp=0.03, flutter_fixedfreq=6, flutter_variationfreq=2,
            hpf=60,hpfqr=0.6,
            lpf=18000,lpfqr=0.6,
            buf;
            var snd=SoundIn.ar([0,1]);
            var auxin=In.kr(auxinBus);//bus
            var tape_wet=In.kr(tape_wetBus);//bus
            var tape_bias=In.kr(tape_biasBus);//bus
            var tape_sat=In.kr(tape_satBus);//bus
            var tape_drive=In.kr(tape_driveBus);//bus
            var dist_wet=In.kr(dist_wetBus);//bus
            var dist_drive=In.kr(dist_driveBus);//bus
            var dist_bias=In.kr(dist_biasBus);//bus
            var dist_low=In.kr(dist_lowBus);//bus
            var dist_high=In.kr(dist_highBus);//bus
            var dist_shelf=In.kr(dist_shelfBus);//bus
            snd=snd+(auxin*SoundIn.ar([0,1]));
            snd=SelectX.ar(Lag.kr(tape_wet,1),[snd,AnalogTape.ar(snd,tape_bias,tape_sat,tape_drive,tape_oversample,mode)]);
            snd=SelectX.ar(Lag.kr(dist_wet,1),[snd,AnalogVintageDistortion.ar(snd,dist_drive,dist_bias,dist_low,dist_high,dist_shelf,dist_oversample)]);          
            snd=RHPF.ar(snd,hpf,hpfqr);
            snd=RLPF.ar(snd,lpf,lpfqr);
            Out.ar(0,snd*EnvGen.ar(Env.new([0,1],[4])));
        }).add;


        // <mods>
        // msg1 = start value
        // msg2 = final value 
        // msg3 = period
        SynthDef("defMod_dc",{
            arg out, msg1=0,msg2=1.0,msg3=1.0;
            FreeSelf.kr(TDelay.kr(Trig.kr(1)));
            Out.kr(out,DC.kr(msg2));
        }).add;

        SynthDef("defMod_lag",{
            arg out, msg1=0,msg2=1.0,msg3=1.0;
            Out.kr(out,Lag.kr(msg2,msg3));
        }).add;

        SynthDef("defMod_sine",{
            arg out, msg1=2,msg2=0.0,msg3=1.0;
            Out.kr(out,SinOsc.kr(freq:1/msg3).range(msg1,msg2));
        }).add;

        SynthDef("defMod_line",{
            arg out, msg1=0,msg2=1.0,msg3=1.0;
            Out.kr(out,Line.kr(start:msg1,end:msg2,dur:msg3,doneAction:2));
        }).add;


        SynthDef("defMod_xline",{
            arg out, msg1=0,msg2=1.0,msg3=1.0;
            Out.kr(out,XLine.kr(start:msg1+0.00001,end:msg2,dur:msg3,doneAction:2));
        }).add;

        context.server.sync;
        synTape=Synth.tail(context.server,"defTape");


        // <Tape>
        [\auxin,\tape_wet,\tape_bias,\tape_sat,\tape_drive,\dist_wet,\dist_drive,\dist_bias,\dist_low,\dist_high,\dist_shelf].do({ arg fx;
            var domain="tape";
            var key=domain++"_"++fx;
            fxbus.put(key,Bus.control(context.server,1));
            fxbus.at(key).value=1.0;
            // MAKE SURE TO CHANGE THE SYNTH
            synTape.set(fx++"Bus",fxbus.at(key).index);
            this.addCommand(key, "sfff", { arg msg;
                if (key=="lag",{
                    if (fxsyn.at(key).isNil,{
                        fxsyn.put(key,Synth.new("defMod_"++msg[1].asString,[\out,fxbus.at(key),\msg1,msg[2],\msg2,msg[3],\msg3,msg[4]]));
                    },{
                        fxsyn.at(key).set(\msg1,msg[2],\msg2,msg[3],\msg3,msg[4]);
                    });
                },{
                    if (fxsyn.at(key).notNil,{
                        fxsyn.at(key).free;
                    });
                    fxsyn.put(key,Synth.new("defMod_"++msg[1].asString,[\out,fxbus.at(key),\msg1,msg[2],\msg2,msg[3],\msg3,msg[4]]));
                })
            });
        });
        // </Tape>
  }

  free {
    responder.free;
    // onsetdetector.free;
    synth.free;
    // recorder.free;
    buffer1.free;
    buffer2.free;
    fxbus.keysValuesDo{ |key,value| value.free };
    fxsyn.keysValuesDo{ |key,value| value.free };
    synTape.free;

  }
} 
