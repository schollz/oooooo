Engine_SimpleDelayKolor : CroneEngine {
  //var <responder; 
  //var <onsetdetector;
  var synth;
  // var recorder;
  var buffer1;
  var buffer2;
  var bufnum1=12;
  var bufnum2=13;
	
// Kolor specific v0.1.0
	var sampleBuffKolor;
	var samplePlayerKolor;
	// Kolor ^

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc { 
    buffer1 = Buffer.alloc(context.server,48000 * 0.03, 1,bufnum:bufnum1); 
    buffer2 = Buffer.alloc(context.server,48000 * 0.03, 1,bufnum:bufnum2); 
    synth = { arg delay=0.03, volume=0.0;
      var input = SoundIn.ar([0, 1]);
      BufDelayC.ar([bufnum1,bufnum2], input, delayTime:0.03, mul:volume)
    }.play(context.server);

    // onset detection!
    // onsetdetector = { arg onset_threshold=0.1, onsets_delay = 0, volume=0;
    //   var input = SoundIn.ar([0, 1]);
    //   var chain = FFT(LocalBuf(512), input);
    //   var onsets = Onsets.kr(chain, onset_threshold, \rcomplex, floor: 0.02,mingap:20);
    //   SendTrig.kr(onsets, 0, 1);
    // }.play(context.server);
    // responder = OSCFunc(
    //     { 
    //       arg msg, time; 
    //       // postln('['++time++']');
    //       NetAddr("127.0.0.1", 10111).sendMsg("onset",1,time); 
    //     },'/tr', context.server.addr);

    this.addCommand("delay", "f", { arg msg; synth.set(\delay, msg[1]); });
    this.addCommand("volume", "f", { arg msg; synth.set(\volume, msg[1]);});
		
// Kolor specific v0.1.0
		sampleBuffKolor = Array.fill(12, { arg i; 
			Buffer.read(context.server, "/home/we/dust/code/kolor/samples/silence.wav"); 
		});

		(0..12).do({arg i; 
			SynthDef("player"++i,{ arg sampleBufnum=0, t_trig=0, lfolfo=0.0, currentTime=0.0, 
				ampMin=0.0, ampMax=0.0, ampLFOMin=0.0, ampLFOMax=0.0, 
				rateMin=1.0, rateMax=1.0, rateLFOMin=0.0, rateLFOMax=0.0,
				panMin=0.0, panMax=0.0, panLFOMin=0.0, panLFOMax=0.0,
				lpfMin=20000.0, lpfMax=20000.0, lpfLFOMin=0.0, lpfLFOMax=0.0,
				resonanceMin=2.0, resonanceMax=2.0, resonanceLFOMin=0.0, resonanceLFOMax=0.0,
				hpfMin=10.0, hpfMax=10.0, hpfLFOMin=0.0, hpfLFOMax=0.0,
				sampleStartMin=0.0, sampleStartMax=0.0, sampleStartLFOMin=0.0, sampleStartLFOMax=0.0,
				sampleEndMin=1.0, sampleEndMax=1.0, sampleEndLFOMin=0.0, sampleEndLFOMax=0.0,
				retrigMin=1.0, retrigMax=1.0, retrigLFOMin=0.0, retrigLFOMax=0.0,
				delaySendMin=1.0, delaySendMax=1.0, delaySendLFOMin=0.0, delaySendLFOMax=0.0,
				delayFeedbackMin=1.0, delayFeedbackMax=1.0, delayFeedbackLFOMin=0.0, delayFeedbackLFOMax=0.0,
				secondsPerBeat=0.5,t_gate=0;
				
				var amp, rate, pan, lpf, resonance, hpf, sampleStart, sampleEnd, snd, bufsnd, delaySend, delayFeedback, retrig;
				
				// lfo modulation
				amp = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*ampLFOMin).mod(2*pi),mul:(ampLFOMax-ampLFOMin),add:(ampLFOMax+ampLFOMin)/2),
					(currentTime*2*pi*ampLFOMin).mod(2*pi),mul:(ampMax-ampMin)/2,add:(ampMax+ampMin)/2
				);
				rate = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*rateLFOMin).mod(2*pi),mul:(rateLFOMax-rateLFOMin),add:(rateLFOMax+rateLFOMin)/2),
					(currentTime*2*pi*rateLFOMin).mod(2*pi),mul:(rateMax-rateMin)/2,add:(rateMax+rateMin)/2
				);
				pan = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*panLFOMin).mod(2*pi),mul:(panLFOMax-panLFOMin),add:(panLFOMax+panLFOMin)/2),
					(currentTime*2*pi*panLFOMin).mod(2*pi),mul:(panMax-panMin)/2,add:(panMax+panMin)/2
				);
				lpf = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*lpfLFOMin).mod(2*pi),mul:(lpfLFOMax-lpfLFOMin),add:(lpfLFOMax+lpfLFOMin)/2),
					(currentTime*2*pi*lpfLFOMin).mod(2*pi),mul:(lpfMax-lpfMin)/2,add:(lpfMax+lpfMin)/2
				);
				resonance = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*resonanceLFOMin).mod(2*pi),mul:(resonanceLFOMax-resonanceLFOMin),add:(resonanceLFOMax+resonanceLFOMin)/2),
					(currentTime*2*pi*resonanceLFOMin).mod(2*pi),mul:(resonanceMax-resonanceMin)/2,add:(resonanceMax+resonanceMin)/2
				);
				hpf = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*hpfLFOMin).mod(2*pi),mul:(hpfLFOMax-hpfLFOMin),add:(hpfLFOMax+hpfLFOMin)/2),
					(currentTime*2*pi*hpfLFOMin).mod(2*pi),mul:(hpfMax-hpfMin)/2,add:(hpfMax+hpfMin)/2
				);
				sampleStart = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*sampleStartLFOMin).mod(2*pi),mul:(sampleStartLFOMax-sampleStartLFOMin),add:(sampleStartLFOMax+sampleStartLFOMin)/2),
					(currentTime*2*pi*sampleStartLFOMin).mod(2*pi),mul:(sampleStartMax-sampleStartMin)/2,add:(sampleStartMax+sampleStartMin)/2
				);
				sampleEnd = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*sampleEndLFOMin).mod(2*pi),mul:(sampleEndLFOMax-sampleEndLFOMin),add:(sampleEndLFOMax+sampleEndLFOMin)/2),
					(currentTime*2*pi*sampleEndLFOMin).mod(2*pi),mul:(sampleEndMax-sampleEndMin)/2,add:(sampleEndMax+sampleEndMin)/2
				);
				retrig = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*retrigLFOMin).mod(2*pi),mul:(retrigLFOMax-retrigLFOMin),add:(retrigLFOMax+retrigLFOMin)/2),
					(currentTime*2*pi*retrigLFOMin).mod(2*pi),mul:(retrigMax-retrigMin)/2,add:(retrigMax+retrigMin)/2
				);
				delaySend = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*delaySendLFOMin).mod(2*pi),mul:(delaySendLFOMax-delaySendLFOMin),add:(delaySendLFOMax+delaySendLFOMin)/2),
					(currentTime*2*pi*delaySendLFOMin).mod(2*pi),mul:(delaySendMax-delaySendMin)/2,add:(delaySendMax+delaySendMin)/2
				);
				delayFeedback = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*delayFeedbackLFOMin).mod(2*pi),mul:(delayFeedbackLFOMax-delayFeedbackLFOMin),add:(delayFeedbackLFOMax+delayFeedbackLFOMin)/2),
					(currentTime*2*pi*delayFeedbackLFOMin).mod(2*pi),mul:(delayFeedbackMax-delayFeedbackMin)/2,add:(delayFeedbackMax+delayFeedbackMin)/2
				);
				
				bufsnd = BufRd.ar(2,sampleBufnum,
					Phasor.ar(
						trig:t_trig,
						rate:BufRateScale.kr(sampleBufnum)*rate,
						// start:sampleStart*BufFrames.kr(sampleBufnum),
						// end:sampleEnd*BufFrames.kr(sampleBufnum),
						// resetPos:sampleStart*BufFrames.kr(sampleBufnum)
						start:((sampleStart*(rate>0))+(sampleEnd*(rate<0)))*BufFrames.kr(sampleBufnum),
						end:((sampleEnd*(rate>0))+(sampleStart*(rate<0)))*BufFrames.kr(sampleBufnum),
						resetPos:((sampleStart*(rate>0))+(sampleEnd*(rate<0)))*BufFrames.kr(sampleBufnum)
					)
					loop:(retrig>0),
					interpolation:1
				);
				// bufsnd = PlayBuf.ar(2, sampleBufnum,
				// 	rate:rate*BufRateScale.kr(sampleBufnum),
				// 	startPos:sampleStart*BufFrames.kr(sampleBufnum),
				// 	loop:retrig, // if > 0 then it loops, getting stopped by the envelope
				// 	trigger:t_trig);
	        		bufsnd = MoogFF.ar(bufsnd,lpf,resonance);
	        		bufsnd = HPF.ar(bufsnd,hpf);
				snd = Mix.ar([
					Pan2.ar(bufsnd[0],-1+(2*pan),amp),
					Pan2.ar(bufsnd[1],1+(2*pan),amp),
				]);
				Out.ar(0,
					snd*EnvGen.ar(Env([0,1, 1, 0], [0.005,(sampleEnd-sampleStart)/(rate.abs)*(retrig+1)*BufDur.kr(sampleBufnum)-0.015,0.005]),gate:t_gate) +
					CombN.ar(
						snd*EnvGen.ar(Env([0,1, 1, 0], [0.005,(sampleEnd-sampleStart)/(rate.abs)*(retrig+1)*BufDur.kr(sampleBufnum)-0.015,0.005]),gate:t_gate),
						1,secondsPerBeat/8*2,secondsPerBeat/8*delayFeedback,0.75*delaySend // delayFeedback should vary between 2 and 128
					)
				)
			}).add;	
		});

		samplePlayerKolor = Array.fill(12,{arg i;
			Synth("player"++i,[\bufnum:sampleBuffKolor[i]], target:context.xg);
		});

		this.addCommand("kolorsample","is", { arg msg;
			// lua is sending 1-index
			sampleBuffKolor[msg[1]-1].free;
			sampleBuffKolor[msg[1]-1] = Buffer.read(context.server,msg[2]);
		});

		this.addCommand("kolorplay","iffffffffffffffffffffffffffffffffffffffffffffffff", { arg msg;
			// lua is sending 1-index
			samplePlayerKolor[msg[1]-1].set(
				\t_trig,1,
				\currentTime, msg[2],
				\ampMin,msg[3],\ampMax,msg[4],\ampLFOMin,msg[5],\ampLFOMax,msg[6],
				\rateMin,msg[7],\rateMax,msg[8],\rateLFOMin,msg[9],\rateLFOMax,msg[10],
				\panMin,msg[11],\panMax,msg[12],\panLFOMin,msg[13],\panLFOMax,msg[14],
				\lpfMin,msg[15],\lpfMax,msg[16],\lpfLFOMin,msg[17],\lpfLFOMax,msg[18],
				\resonanceMin,msg[19],\resonanceMax,msg[20],\resonanceLFOMin,msg[21],\resonanceLFOMax,msg[22],
				\hpfMin,msg[23],\hpfMax,msg[24],\hpfLFOMin,msg[25],\hpfLFOMax,msg[26],
				\sampleStartMin,msg[27],\sampleStartMax,msg[28],\sampleStartLFOMin,msg[29],\sampleStartLFOMax,msg[30],
				\sampleEndMin,msg[31],\sampleEndMax,msg[32],\sampleEndLFOMin,msg[33],\sampleEndLFOMax,msg[34],
				\retrigMin,msg[35],\retrigMax,msg[36],\retrigLFOMin,msg[37],\retrigLFOMax,msg[38],
				\delaySendMin,msg[39],\delaySendMax,msg[40],\delaySendLFOMin,msg[41],\delaySendLFOMax,msg[42],
				\delayFeedbackMin,msg[43],\delayFeedbackMax,msg[44],\delayFeedbackLFOMin,msg[45],\delayFeedbackLFOMax,msg[46],
				\lfolfo,msg[47],
				\sampleBufnum,sampleBuffKolor[msg[48]-1],
				\secondsPerBeat,msg[49],
				\t_gate,1
			);
		});
		// Kolor ^
  }

  free {
    // responder.free;
    // onsetdetector.free;
    synth.free;
    // recorder.free;
    buffer1.free;
    buffer2.free;
		// Kolor specific 0.1.0
		(0..11).do({arg i; sampleBuffKolor[i].free});
		(0..11).do({arg i; samplePlayerKolor[i].free});
		// Kolor ^
  }
} 

