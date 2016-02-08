// First, download LMMS from https://lmms.io
// "LADSPA_PATH".setenv("/Applications/LMMS.app/Contents/lib/lmms/ladspa");
// s.boot;
// s.quit;
(
SynthDef('sonic-pi-fx_tube-warmth', {
	arg drive = 0.2572, tape_blend = 1, out_bus=0, in_bus=0;
	var source, result;
	source = In.ar(in_bus,2);
	result = LADSPA.ar(1, 2158, drive*10, tape_blend*10, source);

	Out.ar(out_bus, result.dup);
}).writeDefFile(PathName.new(thisProcess.nowExecutingPath).pathOnly +/+ "../../../compiled/");
)
