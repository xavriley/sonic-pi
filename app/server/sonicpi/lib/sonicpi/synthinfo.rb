#--
# This file is part of Sonic Pi: http://sonic-pi.net
# Full project source: https://github.com/samaaron/sonic-pi
# License: https://github.com/samaaron/sonic-pi/blob/master/LICENSE.md
#
# Copyright 2013, 2014, 2015 by Sam Aaron (http://sam.aaron.name).
# All rights reserved.
#
# Permission is granted for use, copying, modification, and
# distribution of modified versions of this work as long as this
# notice is included.
#++
require_relative "version"

module SonicPi

  class BaseInfo
    attr_reader :scsynth_name, :info

    def initialize
      @scsynth_name = "#{prefix}#{synth_name}"
      @info = default_arg_info.merge(specific_arg_info)
    end

    def rrand(min, max)
      range = (min - max).abs
      r = rand(range.to_f)
      smallest = [min, max].min
      r + smallest
    end

    def doc
       "Please write documentation!"
    end

    def arg_defaults
      raise "please implement arg_defaults for #{self.class}"
    end

    def name
      raise "please implement name for synth info: #{self.class}"
    end

    def category
      raise "please implement category for synth info: #{self.class}"
    end

    def prefix
      ""
    end

    def synth_name
      raise "Please implement synth_name for #{self.class}"
    end

    def introduced
      raise "please implement introduced version for synth info: #{self.class}"
    end

    def trigger_with_logical_clock?
      raise "please implement trigger_with_logical_clock? for synth info: #{self.class}"
    end

    def args
      args_defaults.keys
    end

    def arg_doc(arg_name)
      info = arg_info[arg_name.to_sym]
      info[:doc] if info
    end

    def arg_default(arg_name)
      arg_defaults[arg_name.to_sym]
    end

    def ctl_validate!(*args)
      args_h = resolve_synth_opts_hash_or_array(args)

      args_h.each do |k, v|
        k_sym = k.to_sym
        arg_information = @info[k_sym] || {}
        arg_validations = arg_information[:validations] || []
        arg_validations(k_sym).each do |v_fn, msg|
          raise "Value of argument #{k_sym.inspect} #{msg}, got #{v.inspect}." unless v_fn.call(args_h)
        end

        raise "Invalid arg modulation attempt for #{synth_name.to_sym.inspect}. Argument #{k_sym.inspect} is not modulatable" unless arg_information[:modulatable]

      end
    end

    def validate!(*args)
      args_h = resolve_synth_opts_hash_or_array(args)

      args_h.each do |k, v|
        k_sym = k.to_sym
#        raise "Value of argument #{k_sym.inspect} must be a number, got #{v.inspect}." unless v.is_a? Numeric

        arg_validations(k_sym).each do |v_fn, msg|
          raise "Value of argument #{k_sym.inspect} #{msg}, got #{v.inspect}." unless v_fn.call(args_h)
        end
      end
    end

    def arg_validations(arg_name)
      arg_information = @info[arg_name] || {}
      arg_information[:validations] || []
    end

    def bpm_scale_args
      return @cached_bpm_scale_args if @cached_bpm_scale_args

      args_to_scale = []
      @info.each do |k, v|
        args_to_scale << k if v[:bpm_scale]
      end

      @cached_bpm_scale_args = args_to_scale
    end

    def arg_info
      #Specifically for doc usage. Consider changing name do doc_info
      #Don't call as part of audio loops as slow. Use .info directly
      res = {}
      arg_defaults.each do |arg, default|
        if m = /(.*)_slide/.match(arg.to_s) then
          parent = m[1].to_sym
          res[parent][:slidable] = true
          # and don't add to arg_info table
        else
          default_info = @info[arg] || {}
          constraints = (default_info[:validations] || []).map{|el| el[1]}
          new_info = {}
          new_info[:doc] = default_info[:doc]
          new_info[:default] = default_info[:default] || default
          new_info[:bpm_scale] = default_info[:bpm_scale]
          new_info[:constraints] = constraints
          new_info[:modulatable] = default_info[:modulatable]
          res[arg] = new_info
        end
      end

      res

    end

    def kill_delay(args_h)
      1
    end

    def generic_slide_doc(k)
      return "Amount of time (in beats) for the #{k} value to change. A long #{k}_slide value means that the #{k} takes a long time to slide from the previous value to the new value. A #{k}_slide of 0 means that the #{k} instantly changes to the new value."
    end

    def generic_slide_curve_doc(k)
      return "Shape of the slide curve (only honoured if slide shape is 5). 0 means linear and positive and negative numbers curve the segment up and down respectively."
    end

    def generic_slide_shape_doc(k)
      return "Shape of curve. 0: step, 1: linear, 3: sine, 4: welch, 5: custom (use curvature param), 6: squared, 7: cubed"
    end

    private

    def v_sum_less_than_oet(arg1, arg2, max)
      [lambda{|args| (args[arg1] + args[arg2]) <= max}, "added to #{arg2.to_sym} must be less than or equal to #{max}"]
    end

    def v_positive(arg)
      [lambda{|args| args[arg] >= 0}, "must be zero or greater"]
    end

    def v_positive_not_zero(arg)
      [lambda{|args| args[arg] > 0}, "must be greater than zero"]
    end

    def v_between_inclusive(arg, min, max)
      [lambda{|args| args[arg] >= min && args[arg] <= max}, "must be a value between #{min} and #{max} inclusively"]
    end

    def v_between_exclusive(arg, min, max)
      [lambda{|args| args[arg] > min && args[arg] < max}, "must be a value between #{min} and #{max} exclusively"]
    end

    def v_less_than(arg,  max)
      [lambda{|args| args[arg] < max}, "must be a value less than #{max}"]
    end

    def v_less_than_oet(arg,  max)
      [lambda{|args| args[arg] <= max}, "must be a value less than or equal to #{max}"]
    end

    def v_greater_than(arg,  min)
      [lambda{|args| args[arg] > min}, "must be a value greater than #{min}"]
    end

    def v_greater_than_oet(arg,  min)
      [lambda{|args| args[arg] >= min}, "must be a value greater than or equal to #{min}"]
    end

    def v_one_of(arg, valid_options)
      [lambda{|args| valid_options.include?(args[arg])}, "must be one of the following values: #{valid_options.inspect}"]
    end

    def v_not_zero(arg)
      [lambda{|args| args[arg] != 0}, "must not be zero"]
    end

    def default_arg_info
      {
        :mix =>
        {
          :doc => "The amount (percentage) of FX present in the resulting sound represented as a value between 0 and 1. For example, a mix of 0 means that only the original sound is heard, a mix of 1 means that only the FX is heard (typically the default) and a mix of 0.5 means that half the original and half of the FX is heard. ",
          :validations => [v_between_inclusive(:mix, 0, 1)],
          :modulatable => true
        },

        :mix_slide =>
        {
          :doc => "Amount of time (in beats) for the mix value to change. A long slide value means that the mix takes a long time to slide from the previous value to the new value. A slide of 0 means that the mix instantly changes to the new value.",
          :validations => [v_positive(:mix_slide)],
          :modulatable => true
        },

        :note =>
        {
          :doc => "Note to play. Either a MIDI number or a symbol representing a note. For example: `30, 52, :C, :C2, :Eb4`, or `:Ds3`",
          :validations => [v_positive(:note)],
          :modulatable => true
        },

        :note_slide =>
        {
          :doc => "Amount of time (in beats) for the note to change. A long slide value means that the note takes a long time to slide from the previous note to the new note. A slide of 0 means that the note instantly changes to the new note.",
          :validations => [v_positive(:note_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :amp =>
        {
          :doc => "The amplitude of the sound. Typically a value between 0 and 1. Higher amplitudes may be used, but won't make the sound louder, it will just reduce the quality of all the sounds currently being played (due to compression.)",
          :validations => [v_positive(:amp)],
          :modulatable => true
        },

        :amp_slide =>
        {
          :doc => "Amount of time (in beats) for the amplitude (amp) to change. A long slide value means that the amp takes a long time to slide from the previous amplitude to the new amplitude. A slide of 0 means that the amplitude instantly changes to the new amplitude.",
          :validations => [v_positive(:amp_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :pan =>
        {

          :doc => "Position of sound in stereo. With headphones on, this means how much of the sound is in the left ear, and how much is in the right ear. With a value of -1, the soundis completely in the left ear, a value of 0 puts the sound equally in both ears and a value of 1 puts the sound in the right ear. Values in between -1 and 1 move the sound accordingly.",
          :validations => [v_between_inclusive(:pan, -1, 1)],
          :modulatable => true
        },

        :pan_slide =>
        {
          :doc => "Amount of time (in beats) for the pan to change. A long slide value means that the pan takes a long time to slide from the previous pan position to the new pan position. A slide of 0 means that the pan instantly changes to the new pan position.",
          :validations => [v_positive(:pan_slide)],
          :modulatable => true,
          :bpm_scale => true
        },


        :attack =>
        {
          :doc => "Amount of time (in beats) for sound to reach full amplitude (attack_level). A short attack (i.e. 0.01) makes the initial part of the sound very percussive like a sharp tap. A longer attack (i.e 1) fades the sound in gently. Full length of sound is attack + decay + sustain + release.",
          :validations => [v_positive(:attack)],
          :modulatable => false,
          :bpm_scale => true
        },

        :decay =>
        {
          :doc => "Amount of time (in beats) for the sound to move from full amplitude (attack_level) to the sustain amplitude (sustain_level).",
          :validations => [v_positive(:decay)],
          :modulatable => false,
          :bpm_scale => true
        },

        :sustain =>
        {
          :doc => "Amount of time (in beats) for sound to remain at sustain level amplitude. Longer sustain values result in longer sounds. Full length of sound is attack + decay + sustain + release.",
          :validations => [v_positive(:sustain)],
          :modulatable => false,
          :bpm_scale => true
        },

        :release =>
        {
          :doc => "Amount of time (in beats) for sound to move from sustain level amplitude to silent. A short release (i.e. 0.01) makes the final part of the sound very percussive (potentially resulting in a click). A longer release (i.e 1) fades the sound out gently. Full length of sound is attack + decay + sustain + release.",
          :validations => [v_positive(:release)],
          :modulatable => false,
          :bpm_scale => true
        },

        :attack_level =>
        {
          :doc => "Amplitude level reached after attack phase and immediately before decay phase",
          :validations => [v_positive(:attack_level)],
          :modulatable => false
        },

        :sustain_level =>
        {
          :doc => "Amplitude level reached after decay phase and immediately before release phase.",
          :validations => [v_positive(:sustain_level)],
          :modulatable => false
        },

        :env_curve =>
        {
          :doc => "Select the shape of the curve between levels in the envelope. 1=linear, 2=exponential, 3=sine, 4=welch, 6=squared, 7=cubed",
          :validations => [v_one_of(:env_curve, [1, 2, 3, 4, 6, 7])],
          :modulatable => false
        },

        :cutoff =>
        {
          :doc => "MIDI note representing the highest frequencies allowed to be present in the sound. A low value like 30 makes the sound round and dull, a high value like 100 makes the sound buzzy and crispy.",
          :validations => [v_positive(:cutoff), v_less_than(:cutoff, 131)],
          :modulatable => true
        },

        :cutoff_slide =>
        {
          :doc => "Amount of time (in beats) for the cutoff value to change. A long cutoff_slide value means that the cutoff takes a long time to slide from the previous value to the new value. A cutoff_slide of 0 means that the cutoff instantly changes to the new value.",
          :validations => [v_positive(:cutoff_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :detune =>
        {
          :doc => "Distance (in MIDI notes) between components of sound. Affects thickness, sense of tuning and harmony. Tiny values such as 0.1 create a thick sound. Larger values such as 0.5 make the tuning sound strange. Even bigger values such as 5 create chord-like sounds.",
          :validations => [],
          :modulatable => true
        },

        :detune_slide =>
        {
          :doc => generic_slide_doc(:detune),
          :validations => [v_positive(:detune_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_phase =>
        {
          :doc => "Phase duration in beats of oscillations between the two notes. Time it takes to switch betwen the notes.",
          :validations => [v_positive_not_zero(:mod_phase)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_phase_offset =>
        {
          :doc => "Initial modulation phase offset (a value between 0 and 1).",
          :validations => [v_between_inclusive(:mod_phase_offset, 0, 1)],
          :modulatable => false
        },

        :mod_phase_slide =>
        {
          :doc => generic_slide_doc(:mod_phase),
          :validations => [v_positive(:mod_phase_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_range =>
        {
          :doc => "The size of gap between modulation notes. A gap of 12 is one octave.",
          :modulatable => true
        },

        :mod_range_slide =>
        {
          :doc => generic_slide_doc(:mod_range),
          :validations => [v_positive(:mod_range_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :res =>
        {
          :doc => "Filter resonance as a value between 0 and 1. Large amounts of resonance (a res: near 1) can create a whistling sound around the cutoff frequency. Smaller values produce less resonance.",
          :validations => [v_positive(:res), v_less_than_oet(:res, 1)],
          :modulatable => true
        },

        :res_slide =>
        {
          :doc => generic_slide_doc(:res),
          :validations => [v_positive(:res_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :pulse_width =>
        {
          :doc => "The width of the pulse wave as a value between 0 and 1. A width of 0.5 will produce a square wave. Different values will change the timbre of the sound. Only valid if wave is type pulse.",
          :validations => [v_between_exclusive(:pulse_width, 0, 1)],
          :modulatable => true
        },

        :pulse_width_slide =>
        {
          :doc => "Time in beats for pulse width to change.",
          :validations => [v_positive(:pulse_width_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_pulse_width =>
        {
          :doc => "The width of the modualted pulse wave as a value between 0 and 1. A width of 0.5 will produce a square wave. Only valid if mod wave is type pulse.",
          :validations => [v_between_exclusive(:mod_pulse_width, 0, 1)],
          :modulatable => true
        },

        :mod_pulse_width_slide =>
        {
          :doc => "Time in beats for modulated pulse width to change.",
          :validations => [v_positive(:mod_pulse_width_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_wave =>
        {
          :doc => "Wave shape of mod wave. 0=saw wave, 1=pulse, 2=triangle wave and 3=sine wave.",
          :validations => [v_one_of(:mod_wave, [0, 1, 2, 3])],
          :modulatable => true
        },

        :mod_invert_wave =>
        {
          :doc => "Invert mod waveform (i.e. flip it on the y axis). 0=normal wave, 1=inverted wave.",
          :validations => [v_one_of(:mod_invert_wave, [0, 1])],
          :modulatable => true
        }

      }
    end

    def specific_arg_info
      {}
    end

  end

  class SynthInfo < BaseInfo
    def category
      :general
    end

    def prefix
      "sonic-pi-"
    end
  end

  class SonicPiSynth < SynthInfo
  end

  class DullBell < SonicPiSynth
    def name
      "Dull Bell"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "dull_bell"
    end

    def doc
      "A simple dull dischordant bell sound."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2
      }
    end
  end

  class PrettyBell < DullBell
    def name
      "Pretty Bell"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "pretty_bell"
    end

    def doc
      "A pretty bell sound. Works well with short attacks and long delays."
    end
  end

  class Beep < SonicPiSynth
    def name
      "Sine Wave"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "beep"
    end

    def doc
      "A simple pure sine wave. The sine wave is the simplest, purest sound there is and is the fundamental building block of all noise. The mathematician Fourier demonstrated that any sound could be built out of a number of sine waves (the more complex the sound, the more sine waves needed). Have a play combining a number of sine waves to design your own sounds!"
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2
      }
    end
  end

  class Saw < Beep
    def name
      "Saw Wave"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "saw"
    end

    def doc
      "A saw wave with a low pass filter. Great for using with FX such as the built in low pass filter (available via the cutoff arg) due to the complexity and thickness of the sound."
    end
  end


  class Square < SonicPiSynth
    def name
      "Square Wave"
    end

    def introduced
      Version.new(2,2,0)
    end

    def synth_name
      "square"
    end

    def doc
      "A simple pulse wave with a low pass filter. This defaults to a square wave, but the timbre can be changed dramatically by adjusting the pulse_width arg between 0 and 1. The pulse wave is thick and deavy with lower notes and is a great ingredient for bass sounds."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0
      }
    end
  end

  class Pulse < Square
    def name
      "Pulse Wave"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "pulse"
    end

    def doc
      "A simple square wave with a low pass filter.  The square wave is thick and deavy with lower notes and is a great ingredient for bass sounds. If you wish to modulate the width of the square wave see the synth pulse."
    end

    def arg_defaults
      super.merge({
        :pulse_width => 0.5,
        :pulse_width_slide => 0,
        :pulse_width_slide_shape => 5,
        :pulse_width_slide_curve => 0})
    end
  end

  class Tri < Pulse
    def name
      "Triangle Wave"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "tri"
    end

    def doc
      "A simple triangle wave with a low pass filter."
    end
  end

  class DSaw < SonicPiSynth
    def name
      "Detuned Saw wave"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "dsaw"
    end

    def doc
      "A pair of detuned saw waves passed through a low pass filter. Two saw waves with slightly different frequencies generates a nice thick sound which is the basis for a lot of famous synth sounds. Thicken the sound by increasing the detune value, or create an octave-playing synth by choosing a detune of 12 (12 MIDI notes is an octave)."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :detune => 0.1,
        :detune_slide => 0,
        :detune_slide_shape => 5,
        :detune_slide_curve => 0,
      }
    end
  end


  class FM < SonicPiSynth
    def name
      "Basic FM synthesis"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fm"
    end

    def doc
      "A sine wave with a fundamental frequency which is modulated at audio rate by another sine wave with a specific modulation division and depth. Useful for generated a wide range of sounds by playing with the divisor and depth params. Great for deep powerful bass and crazy 70s sci-fi sounds."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,

        :divisor => 2,
        :divisor_slide => 0,
        :divisor_slide_shape => 5,
        :divisor_slide_curve => 0,
        :depth => 1,
        :depth_slide => 0,
        :depth_slide_shape => 5,
        :depth_slide_curve => 0,
      }
    end

    def specific_arg_info
      {
        :divisor =>
        {
          :doc => "Modifies the frequency of the modulator oscillator relative to the carrier. Don't worry too much about what this means - just try different numbers out!",
          :validations => [],
          :modulatable => true
        },

        :divisor_slide =>
        {
          :doc => generic_slide_doc(:divisor),
          :validations => [v_positive(:divisor_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :depth =>
        {
          :doc => "Modifies the depth of the carrier wave used to modify fundamental frequency. Don't worry too much about what this means - just try different numbers out!",
          :validations => [],
          :modulatable => true
        },

        :depth_slide =>
        {
          :doc => generic_slide_doc(:depth),
          :validations => [v_positive(:depth_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }

    end
  end

  class ModFM < FM

    def name
      "Basic FM synthesis with frequency modulation."
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "mod_fm"
    end

    def doc
      "The FM synth modulating between two notes - the duration of the modulation can be modified using the mod_phase arg, the range (number of notes jumped between) by the mod_range arg and the width of the jumps by the mod_width param. The FM synth is sine wave with a fundamental frequency which is modulated at audio rate by another sine wave with a specific modulation division and depth. Useful for generated a wide range of sounds by playing with the `:divisor` and `:depth` params. Great for deep powerful bass and crazy 70s sci-fi sounds."
    end

    def arg_defaults
      super.merge({
                    :mod_phase => 0.25,
                    :mod_range => 5,
                    :mod_pulse_width => 0.5,
                    :mod_phase_offset => 0,
                    :mod_invert_wave => 0,
                    :mod_wave => 1
                  })
    end


  end

  class ModSaw < SonicPiSynth
    def name
      "Modulated Saw Wave"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "mod_saw"
    end

    def doc
      "A saw wave passed through a low pass filter which modulates between two separate notes via a variety of control waves."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :mod_phase => 0.25,
        :mod_phase_slide => 0,
        :mod_phase_slide_shape => 5,
        :mod_phase_slide_curve => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_range_slide_shape => 5,
        :mod_range_slide_curve => 0,
        :mod_pulse_width => 0.5,
        :mod_pulse_width_slide => 0,
        :mod_pulse_width_slide_shape => 5,
        :mod_pulse_width_slide_curve => 0,
        :mod_phase_offset => 0,
        :mod_invert_wave => 0,
        :mod_wave => 1

      }
    end
  end

  class ModDSaw < SonicPiSynth
    def name
      "Modulated Detuned Saw Waves"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "mod_dsaw"
    end

    def doc
      "A pair of detuned saw waves (see the dsaw synth) which are modulated between two fixed notes at a given rate."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :mod_phase => 0.25,

        :mod_phase_slide => 0,
        :mod_phase_slide_shape => 5,
        :mod_phase_slide_curve => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_range_slide_shape => 5,
        :mod_range_slide_curve => 0,
        :mod_pulse_width => 0.5,
        :mod_pulse_width_slide => 0,
        :mod_pulse_width_slide_shape => 5,
        :mod_pulse_width_slide_curve => 0,
        :mod_phase_offset => 0,
        :mod_invert_wave => 0,
        :mod_wave => 1,
        :detune => 0.1,
        :detune_slide => 0,
        :detune_slide_shape => 5,
        :detune_slide_curve => 0,
      }
    end
  end


  class ModSine < SonicPiSynth
    def name
      "Modulated Sine Wave"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "mod_sine"
    end

    def doc
      "A sine wave passed through a low pass filter which modulates between two separate notes via a variety of control waves."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :mod_phase => 0.25,
        :mod_phase_slide => 0,
        :mod_phase_slide_shape => 5,
        :mod_phase_slide_curve => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_range_slide_shape => 5,
        :mod_range_slide_curve => 0,
        :mod_pulse_width => 0.5,
        :mod_pulse_width_slide => 0,
        :mod_pulse_width_slide_shape => 5,
        :mod_pulse_width_slide_curve => 0,
        :mod_phase_offset => 0,
        :mod_invert_wave => 0,
        :mod_wave => 1

      }
    end
  end

  class ModTri < SonicPiSynth
    def name
      "Modulated Triangle Wave"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "mod_tri"
    end

    def doc
      "A triangle wave passed through a low pass filter which modulates between two separate notes via a variety of control waves."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :mod_phase => 0.25,
        :mod_phase_slide => 0,
        :mod_phase_slide_shape => 5,
        :mod_phase_slide_curve => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_range_slide_shape => 5,
        :mod_range_slide_curve => 0,
        :mod_pulse_width => 0.5,
        :mod_pulse_width_slide => 0,
        :mod_pulse_width_slide_shape => 5,
        :mod_pulse_width_slide_curve => 0,
        :mod_phase_offset => 0,
        :mod_invert_wave => 0,
        :mod_wave => 1
      }
    end
  end


  class ModPulse < SonicPiSynth
    def name
      "Modulated Pulse"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "mod_pulse"
    end

    def doc
      "A pulse wave with a low pass filter modulating between two notes via a variety of control waves (see mod_wave: arg). The pulse wave defaults to a square wave, but the timbre can be changed dramatically by adjusting the pulse_width arg between 0 and 1."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :mod_phase => 0.25,
        :mod_phase_slide => 0,
        :mod_phase_slide_shape => 5,
        :mod_phase_slide_curve => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_range_slide_shape => 5,
        :mod_range_slide_curve => 0,
        :mod_pulse_width => 0.5,
        :mod_pulse_width_slide => 0,
        :mod_pulse_width_slide_shape => 5,
        :mod_pulse_width_slide_curve => 0,
        :mod_phase_offset => 0,
        :mod_invert_wave => 0,
        :mod_wave => 1,
        :pulse_width => 0.5,
        :pulse_width_slide => 0,
        :pulse_width_slide_shape => 5,
        :pulse_width_slide_curve => 0,
      }
    end
  end


  class TB303 < SonicPiSynth
    def name
      "TB-303 Emulation"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "tb303"
    end

    def doc
      "Emulation of the classic Roland TB-303 Bass Line synthesiser. Overdrive the res (i.e. use very large values) for that classic late 80s acid sound. "
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 120,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :cutoff_min => 30,
        :cutoff_min_slide => 0,
        :cutoff_min_slide_shape => 5,
        :cutoff_min_slide_curve => 0,
        :cutoff_attack => :attack,
        :cutoff_decay => :decay,
        :cutoff_sustain => :sustain,
        :cutoff_release => :release,
        :cutoff_attack_level => 1,
        :cutoff_sustain_level => 1,
        :res => 0.9,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
        :wave => 0,
        :pulse_width => 0.5,
        :pulse_width_slide => 0,
        :pulse_width_slide_shape => 5,
        :pulse_width_slide_curve => 0,
      }
    end

    def specific_arg_info
      {
        :cutoff_min =>
        {
          :doc => "The minimum  cutoff value.",
          :validations => [v_less_than_oet(:cutoff_min, 130)],
          :modulatable => true
        },

        :cutoff_min_slide =>
        {
          :doc => generic_slide_doc(:cutoff_min),
          :validations => [v_positive(:cutoff_min_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :cutoff =>
        {
          :doc => "The maximum cutoff value as a MIDI note",
          :validations => [v_less_than_oet(:cutoff, 130)],
          :modulatable => true
        },

        :cutoff_slide =>
        {
          :doc => generic_slide_doc(:cutoff),
          :validations => [v_positive(:cutoff_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :cutoff_attack_level =>
        {
          :doc => "The peak cutoff (value of cutoff at peak of attack) as a value between 0 and 1 where 0 is the :cutoff_min and 1 is the :cutoff value",
          :validations => [v_between_inclusive(:cutoff_attack_level, 0, 1)],
          :modulatable => false
        },

        :cutoff_sustain_level =>
        {
          :doc => "The sustain cutoff (value of cutoff at sustain time) as a value between 0 and 1 where 0 is the :cutoff_min and 1 is the :cutoff value.",
          :validations => [v_between_inclusive(:cutoff_sustain_level, 0, 1)],
          :modulatable => false
        },

        :cutoff_attack =>
        {
          :doc => "Attack time for cutoff filter. Amount of time (in beats) for sound to reach full cutoff value. Default value is set to match amp envelope's attack value.",
          :validations => [v_positive(:cutoff_attack)],
          :modulatable => false,
          :default => "attack",
          :bpm_scale => true
        },

        :cutoff_decay =>
        {
          :doc => "Decay time for cutoff filter. Amount of time (in beats) for sound to reach full cutoff value. Default value is set to match amp envelope's decay value.",
          :validations => [v_positive(:cutoff_decay)],
          :modulatable => false,
          :default => "decay",
          :bpm_scale => true
        },

        :cutoff_sustain =>
        {
          :doc => "Amount of time for cutoff value to remain at sustain level in beats. Default value is set to match amp envelope's sustain value.",
          :validations => [v_positive(:cutoff_sustain)],
          :modulatable => false,
          :default => "sustain",
          :bpm_scale => true
        },

        :cutoff_release =>
        {
          :doc => "Amount of time (in beats) for sound to move from cutoff sustain value  to cutoff min value. Default value is set to match amp envelope's release value.",
          :validations => [v_positive(:cutoff_release)],
          :modulatable => false,
          :default => "release",
          :bpm_scale => true
        },

        :cutoff_env_curve =>
        {
          :doc => "Select the shape of the curve between levels in the cutoff envelope. 1=linear, 2=exponential, 3=sine, 4=welch, 6=squared, 7=cubed",
          :validations => [v_one_of(:cutoff_env_curve, [1, 2, 3, 4, 6, 7])],
          :modulatable => false
        },

        :wave =>
        {
          :doc => "Wave type - 0 saw, 1 pulse, 2 triangle. Different waves will produce different sounds.",
          :validations => [v_one_of(:wave, [0, 1, 2])],
          :modulatable => true
        },

      }
    end
  end

  class Supersaw < SonicPiSynth
    def name
      "Supersaw"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "supersaw"
    end

    def doc
      "Thick swirly saw waves sparkling and moving about to create a rich trancy sound."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 130,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :res => 0.7,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,

      }
    end
  end

  class Hoover < SonicPiSynth
    def name
      "Hoover"
    end

    def introduced
      Version.new(2,6,0)
    end

    def synth_name
      "hoover"
    end

    def doc
      "Classic early 90's rave synth - 'a sort of slurry chorussy synth line like the classic Dominator by Human Resource'. Based on Dan Stowell's implementation in SuperCollider and Daniel Turczanski's port to Overtone. Works really well with portamento (see docs for the 'control' method)."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,
        :attack => 0.05,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,
        :cutoff => 130,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
      }
    end
  end

  class Growl < SonicPiSynth
    def name
      "Growl"
    end

    def introduced
      Version.new(2,4,0)
    end

    def synth_name
      "growl"
    end

    def doc
     "A deep rumbling growl with a bright sine shining through at higher notes."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,

        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,

        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0.1,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 130,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :res => 0.7,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
      }
    end
  end

  class DarkAmbience < SonicPiSynth
    def name
      "Dark Ambience"
    end

    def introduced
      Version.new(2,4,0)
    end

    def synth_name
      "dark_ambience"
    end

    def doc
     "A slow rolling bass with a sparkle of light trying to escape the darkness. Great for an ambient sound."
    end

    def arg_defaults
      { :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 110,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :res => 0.7,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,

        :detune1 => 12,
        :detune1_slide => 0,
        :detune1_slide_shape => 5,
        :detune1_slide_curve => 0,

        :detune2 => 24,
        :detune2_slide => 0,
        :detune2_slide_shape => 5,
        :detune2_slide_curve => 0,

        :noise => 0,
        :ring => 0.2,
        :room => 70,
        :reverb_time => 100
      }
    end

    def specific_arg_info
      {
        :ring => {
          :doc => "Amount of ring in the sound. Lower values create a more rough sound, higher values produce a sound with more focus",
          :validations => [v_between_inclusive(:ring, 0.1, 50)],
          :modulatable => true
        },
        :room =>
        {
          :doc => "Room size in squared meters used to calculate the reverb.",
          :validations => [v_greater_than_oet(:room, 0.1), v_less_than_oet(:room, 300)],
          :modulatable => false
        },
        :reverb_time =>
        {
          :doc => "How long in beats the reverb should go on for.",
          :validations => [v_positive(:reverb_time)],
          :modulatable => false
        },
        :detune1 =>
        {
          :doc => "Distance (in MIDI notes) between the main note and the second component of sound. Affects thickness, sense of tuning and harmony.",
        },
        :detune2 =>
        {
          :doc => "Distance (in MIDI notes) between the main note and the third component of sound. Affects thickness, sense of tuning and harmony. Tiny values such as 0.1 create a thick sound.",
        },
        :noise =>
        { :doc => "Noise source. Has a subtle affect on the timbre of the sound. 0=pink noise (the default), 1=brown noise, 2=white noise, 3=clip noise and 4 = grey noise",
          :validations => [v_one_of(:noise, [0, 1, 2, 3, 4])],
          :modulatable => true
        }

      }
    end
  end

  class DarkSeaHorn < SonicPiSynth
    def name
      "Dark Sea Horn"
    end

    def introduced
      Version.new(2,4,0)
    end

    def synth_name
      "dark_sea_horn"
    end

    def doc
     "A deep, rolling sea horn echoing across the empty water."
    end

    def arg_defaults
      {:note => 52,
       :note_slide => 0,
       :note_slide_shape => 5,
       :note_slide_curve => 0,

       :amp => 1,
       :amp_slide => 0,
       :amp_slide_shape => 5,
       :amp_slide_curve => 0,

       :pan => 0,
       :pan_slide => 0,
       :pan_slide_shape => 5,
       :pan_slide_curve => 0,

       :attack => 1,
       :decay => 0,
       :sustain => 0,
       :release => 4.0,
       :attack_level => 1,
       :sustain_level => 1,
       :env_curve => 2
      }
    end
  end

  class Singer < SonicPiSynth
    def name
      "Singer"
    end

    def introduced
      Version.new(2,4,0)
    end

    def synth_name
      "singer"
    end

    def doc
     "Simulating the sound of a vibrato human singer.

     #Bass
     singer note: :G2

     #Tenor
     singer note: :C#4

     #Alto
     singer note: :F#4

     #Soprano
     singer note: :D5"
    end

    def arg_defaults
      {:note => 52,
       :note_slide => 0,
       :note_slide_shape => 5,
       :note_slide_curve => 0,

       :amp => 1,
       :amp_slide => 0,
       :amp_slide_shape => 5,
       :amp_slide_curve => 0,

       :pan => 0,
       :pan_slide => 0,
       :pan_slide_shape => 5,
       :pan_slide_curve => 0,

       :attack => 1,
       :decay => 0,
       :sustain => 0,
       :release => 4.0,
       :attack_level => 1,
       :sustain_level => 1,
       :env_curve => 2
      }
    end

    def specific_arg_info
      {
        :vibrato_speed =>
        {
          :doc => "How fast the singer switches between two notes."
        },
        :vibrato_depth =>
        {
          :doc => "How far the singer travels between notes."
        }
      }
    end
  end

  class Hollow < SonicPiSynth
    def name
      "Hollow"
    end

    def introduced
      Version.new(2,4,0)
    end

    def synth_name
      "hollow"
    end

    def doc
     "A hollow breathy sound constructed from random noise"
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,

        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,

        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 90,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,

        :res => 0.99,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,

        :noise => 1,
        :norm => 0

      }
    end

    def specific_arg_info
      {
        :norm =>
        {
          :doc => "Normalise the audio (make quieter parts of the sample louder and louder parts quieter)- this is similar to the normaliser FX. This may emphasise any clicks caused by clipping. ",
          :validations => [v_one_of(:norm, [0, 1])],
          :modulatable => true
        },

        :res =>
        {
          :doc => "Filter resonance as a value between 0 and 1. Only functional if a cutoff value is specified. Large amounts of resonance (a res: near 1) can create a whistling sound around the cutoff frequency. Smaller values produce less resonance.",
          :validations => [v_positive(:res), v_less_than_oet(:res, 1)],
          :modulatable => true
        },

        :noise =>
        { :doc => "Noise source. Has a subtle affect on the timbre of the sound. 0=pink noise, 1=brown noise (the default), 2=white noise, 3=clip noise and 4ls
=grey noise",
          :validations => [v_one_of(:noise, [0, 1, 2, 3, 4])],
          :modulatable => true
        }
      }
    end
  end

  class Zawa < SonicPiSynth
    def name
      "Zawa"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "zawa"
    end

    def doc
     "Saw wave with oscillating timbre. Produces moving saw waves with a unique character controllable with the control oscillator (usage similar to mod synths). "
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :res => 0.9,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,

        :phase => 1,
        :phase_slide => 0,
        :phase_slide_shape => 5,
        :phase_slide_curve => 0,
        :phase_offset => 0,

        :wave => 3,
        :invert_wave => 0,
        :range => 24,
        :range_slide => 0,
        :range_slide_shape => 5,
        :range_slide_curve => 0,
        :disable_wave => 0,
        :pulse_width => 0.5,
        :pulse_width_slide => 0,
        :pulse_width_slide_shape => 5,
        :pulse_width_slide_curve => 0,

      }
    end

    def specific_arg_info
      {
        :phase =>
        {
          :doc => "Phase duration in beats of timbre modulation.",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => true
        },


        :phase_slide =>
        {
          :doc => generic_slide_doc(:phase),
          :validations => [v_positive(:phase_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :depth_slide =>
        {
          :doc => generic_slide_doc(:depth),
          :validations => [v_positive(:depth_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :phase_offset =>
        {
          :doc => "Initial phase offset of the sync wave (a value between 0 and 1).",
          :validations => [v_between_inclusive(:phase_offset, 0, 1)],
          :modulatable => false
        },

        :range =>
        {
          :doc => "range of the assocatied sync saw in MIDI notes from the main note. Modifies timbre.",
          :validations => [v_between_inclusive(:phase_offset, 0, 90)],
          :modulatable => true
        },

        :range_slide =>
        {
          :doc => generic_slide_doc(:range),
          :validations => [v_positive(:range_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :wave =>
        {
          :doc => "Wave shape controlling freq sync saw wave. 0=saw wave, 1=pulse, 2=triangle wave and 3=sine wave.",
          :validations => [v_one_of(:wave, [0, 1, 2, 3])],
          :modulatable => true
        },

        :invert_wave =>
        {
          :doc => "Invert sync freq control waveform (i.e. flip it on the y axis). 0=uninverted wave, 1=inverted wave.",
          :validations => [v_one_of(:invert_wave, [0, 1])],
          :modulatable => true
        },

        :disable_wave =>
        {
          :doc => "Enable and disable sync control wave (setting to 1 will stop timbre movement).",
          :validations => [v_one_of(:disable_wave, [0, 1])],
          :modulatable => true
        }
      }
    end
  end

  class Prophet < SonicPiSynth
    def name
      "The Prophet"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "prophet"
    end

    def doc
      "Dark and swirly, this synth uses Pulse Width Modulation (PWM) to create a timbre which continually moves around. This effect is created using the pulse ugen which produces a variable width square wave. We then control the width of the pulses using a variety of LFOs - sin-osc and lf-tri in this case. We use a number of these LFO modulated pulse ugens with varying LFO type and rate (and phase in some cases to provide the LFO with a different starting point. We then mix all these pulses together to create a thick sound and then feed it through a resonant low pass filter (rlpf). For extra bass, one of the pulses is an octave lower (half the frequency) and its LFO has a little bit of randomisation thrown into its frequency component for that extra bit of variety."
end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :note_slide_shape => 5,
        :note_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 110,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :res => 0.7,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
      }
    end

  end

 class Pitchless < SonicPiSynth
 end

  class Noise < Pitchless
    def name
      "Noise"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "noise"
    end

    def doc
      "Noise that contains equal amounts of energy at every frequency - comparable to radio static. Useful for generating percussive sounds such as snares and hand claps. Also useful for simulating wind or sea effects."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :cutoff => 110,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :res => 0,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
      }
    end

  end

  class GNoise < Noise
    def name
      "Grey Noise"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "gnoise"
    end

    def doc
      "Generates noise which results from flipping random bits in a word.  The spectrum is emphasised towards lower frequencies. Useful for generating percussive sounds such as snares and hand claps. Also useful for simulating wind or sea effects."
    end
  end

  class BNoise < Noise
    def name
      "Brown Noise"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "bnoise"
    end

    def doc
      "Noise whose spectrum falls off in power by 6 dB per octave. Useful for generating percussive sounds such as snares and hand claps. Also useful for simulating wind or sea effects."
    end

  end

  class PNoise < Noise
    def name
      "Pink Noise"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "pnoise"
    end

    def doc
      "Noise whose spectrum falls off in power by 3 dB per octave. Useful for generating percussive sounds such as snares and hand claps. Also useful for simulating wind or sea effects."
    end

  end

  class CNoise < Noise
    def name
      "Clip Noise"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "cnoise"
    end

    def doc
      "Generates noise whose values are either -1 or 1. This produces the maximum energy for the least peak to peak amplitude. Useful for generating percussive sounds such as snares and hand claps. Also useful for simulating wind or sea effects."
    end

  end

  class StudioInfo < SonicPiSynth

  end

  class SoundIn < StudioInfo
    def name
      "Sound In"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "sound_in"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,
        :input => 0
      }
    end

  end




  class BasicMonoPlayer < StudioInfo
    def name
      "Basic Mono Sample Player (no env)"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "basic_mono_player"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,
        :rate => 1,
        :rate_slide => 0,
        :rate_slide_shape => 5,
        :rate_slide_curve => 0,
        :cutoff => 0,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :res => 0,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
        :norm => 0
      }
    end
  end

  class BasicStereoPlayer < BasicMonoPlayer
    def name
      "Basic Stereo Sample Player (no env)"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "basic_stereo_player"
    end

    def doc
      ""
    end
  end

  class MonoPlayer < StudioInfo
    def name
      "Mono Sample Player"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "mono_player"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,

        :attack => 0,
        :decay => 0,
        :sustain => -1,
        :release => 0,

        :attack_level => 1,
        :sustain_level => 1,
        :env_curve => 2,

        :rate => 1,
        :start => 0,
        :finish => 1,

        :res => 0,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
        :cutoff => 0,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :norm => 0
      }
    end

    def specific_arg_info
      {

        :attack =>
        {
          :doc => "Duration of the attack phase of the envelope.",
          :validations => [v_positive(:attack)],
          :modulatable => false
        },

        :sustain =>
        {
          :doc => "Duration of the sustain phase of the envelope.",
          :validations => [v_positive(:attack)],
          :modulatable => false
        },

        :release =>
        {
          :doc => "Duration of the release phase of the envelope.",
          :validations => [[lambda{|args| v = args[:release] ; (v == -1) || (v >= 0)}, "must either be a positive value or -1"]],
          :modulatable => false
        },

        :rate =>
        {
          :doc => "Rate which to play back with default is 1. Playing the sample at rate 2 will play it back at double the normal speed. This will have the effect of doubling the frequencies in the sample and halving the playback time. Use rates lower than 1 to slow the sample down. Negative rates will play the sample in reverse.",
          :validations => [v_not_zero(:rate)],
          :modulatable => false
        },

        :start =>
        {
          :doc => "A fraction (between 0 and 1) representing where in the sample to start playback. 1 represents the end of the sample, 0.5 half-way through etc.",
          :validations => [v_between_inclusive(:start, 0, 1)],
          :modulatable => false
        },

        :finish =>
        {
          :doc => "A fraction (between 0 and 1) representing where in the sample to finish playback. 1 represents the end of the sample, 0.5 half-way through etc.",
          :validations => [v_between_inclusive(:finish, 0, 1)],
          :modulatable => false
        },

        :norm =>
        {
          :doc => "Normalise the audio (make quieter parts of the sample louder and louder parts quieter)- this is similar to the normaliser FX. This may emphasise any clicks caused by clipping. ",
          :validations => [v_one_of(:norm, [0, 1])],
          :modulatable => true
        },

        :res =>
        {
          :doc => "Filter resonance as a value betwee 0 and 1. Only functional if a cutoff value is specified. Large amounts of resonance (a res: near 1) can create a whistling sound around the cutoff frequency. Smaller values produce less resonance.",
          :validations => [v_positive(:res), v_less_than_oet(:res, 1)],
          :modulatable => true
        }

      }
    end

  end

  class StereoPlayer < MonoPlayer
    def name
      "Stereo Sample Player"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "stereo_player"
    end
  end

  class BaseMixer < StudioInfo

  end

  class BasicMixer < BaseMixer
    def name
      "Basic Mixer"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "basic_mixer"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0.1,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
      }
    end

  end

  class FXInfo < BaseInfo

    def trigger_with_logical_clock?
      true
    end

    def prefix
      "sonic-pi-"
    end

    def default_arg_info
      super.merge({
                    :pre_amp =>
                    {
                      :doc => "Amplification applied to the input signal immediately before it is passed to the FX.",
                      :validations => [v_positive(:pre_amp)],
                      :modulatable => true,
                      :bpm_scale => true
                    },

                    :pre_amp_slide =>
                    {
                      :doc => generic_slide_doc(:pre_amp),
                      :validations => [v_positive(:pre_amp)],
                      :modulatable => true
                    },

                    :phase_offset =>
                    {
                      :doc => "Initial modulation phase offset (a value between 0 and 1).",
                      :validations => [v_between_inclusive(:phase_offset, 0, 1)],
                      :modulatable => false
                    },
                  })
    end
  end

  class FXReverb < FXInfo
    def name
      "Reverb"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_reverb"
    end

    def trigger_with_logical_clock?
      false
    end

    def doc
      "Make the incoming signal sound more spacious or distant as if it were played in a large room or cave. Signal may also be dampened by reducing the ampitude of the higher frequencies."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 0.4,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,

        :room => 0.6,
        :room_slide => 0,
        :room_slide_shape => 5,
        :room_slide_curve => 0,
        :damp => 0.5,
        :damp_slide => 0,
        :damp_slide_shape => 5,
        :damp_slide_curve => 0,
      }
    end


    def kill_delay(args_h)
      [(args_h[:room] * 10) + 1, 11].min
    end


    def specific_arg_info
      {
        :room =>
        {
          :doc => "The room size - a value between 0 (no reverb) and 1 (maximum reverb).",
          :validations => [v_between_inclusive(:room, 0, 1)],
          :modulatable => true
        },

        :damp =>
        {
          :doc => "High frequency dampening - a value between 0 (no dampening) and 1 (maximum dampening)",
          :validations => [v_between_inclusive(:damp, 0, 1)],
          :modulatable => true
        },

        :room_slide =>
        {
          :doc => generic_slide_doc(:room),
          :validations => [v_positive(:room_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :damp_slide =>
        {
          :doc => generic_slide_doc(:damp),
          :validations => [v_positive(:damp_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
    end


  end

  class FXKrush < FXInfo
    def name
      "krush"
    end

    def introduced
      Version.new(2,6,0)
    end

    def synth_name
      "fx_krush"
    end

    def doc
      "Krush that sound!"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :gain => 30,
        :gain_slide => 0,
        :gain_slide_shape => 5,
        :gain_slide__curve => 0,
        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0
      }
    end

    def specific_arg_info
      {
        :gain =>
        {
          :doc => "Amount of crushing to serve",
          :validations => [v_positive_not_zero(:gain)],
          :modulatable => true
        },

        :gain_slide =>
        {
          :doc => generic_slide_doc(:gain),
          :validations => [v_positive(:gain_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
    end

  end

  class FXBitcrusher < FXInfo
    def name
      "Bitcrusher"
    end

    def introduced
      Version.new(2,3,0)
    end

    def synth_name
      "fx_bitcrusher"
    end

    def doc
      "Creates lo-fi output by decimating and deconstructing the incoming audio by lowering both the sample rate and bit depth. The default sample rate for CD audio is 44100, so use values less than that for that crunchy chip-tune sound full of artefacts and bitty distortion. Similarly, the default bit depth for CD audio is 16, so use values less than that for lo-fi sound."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :sample_rate => 10000,
        :sample_rate_slide => 0,
        :sample_rate_slide_shape => 5,
        :sample_rate_slide_curve => 0,
        :bits => 8,
        :bits_slide => 0,
        :bits_slide_shape => 5,
        :bits_slide_curve => 0,
      }
    end

    def specific_arg_info
      {
        :sample_rate =>
        {
          :doc => "The sample rate the audio will be resampled at.",
          :validations => [v_positive_not_zero(:sample_rate)],
          :modulatable => true
        },

        :bits =>
        {
          :doc => "The bit depth of the resampled audio.",
          :validations => [v_positive_not_zero(:bits)],
          :modulatable => true
        },

        :sample_rate_slide =>
        {
          :doc => generic_slide_doc(:sample_rate),
          :validations => [v_positive(:sample_rate_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :bits_slide =>
        {
          :doc => generic_slide_doc(:bits),
          :validations => [v_positive(:bits_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
    end

  end

  class FXLevel < FXInfo
    def name
      "Level Amplifier"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_level"
    end

    def doc
      "Amplitude modifier. All FX have their own amp built in, so it may be the case that you don't specifically need an isolated amp FX. However, it is useful to be able to control the overall amplitude of a number of running synths. All sounds created in the FX block will have their amplitudes multipled by the amp level of this FX. For example, use an amp of 0 to silence all internal synths."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
      }
    end
  end

  class FXEcho < FXInfo
    def name
      "Echo"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_echo"
    end

    def doc
      "Standard echo with variable phase duration (time between echoes) and decay (length of echo fade out). If you wish to have a phase duration longer than 2s, you need to specifiy the longest phase duration you'd like with the arg max_phase. Be warned, echo FX with very long phases can consume a lot of memory and take longer to initialise."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :phase => 0.25,
        :phase_slide => 0,
        :phase_slide_shape => 5,
        :phase_slide_curve => 0,
        :decay => 2,
        :decay_slide => 0,
        :decay_slide_shape => 5,
        :decay_slide_curve => 0,
        :max_phase => 2
      }
    end

    def specific_arg_info
      {
        :max_phase =>
        {
          :doc => "The maximum phase duration in beats.",
          :validations => [v_positive_not_zero(:max_phase)],
          :modulatable => false
        },

        :phase =>
        {
          :doc => "The time between echoes in beats.",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => true

        },

        :phase_slide =>
        {
          :doc => "Slide time in beats between phase values",
          :validations => [v_positive(:phase_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :decay =>
        {
          :doc => "The time it takes for the echoes to fade away in beats.",
          :validations => [v_positive_not_zero(:decay)],
          :modulatable => true,
          :bpm_scale => true
        },

        :decay_slide =>
        {
          :doc => "Slide time in beats between decay times",
          :validations => [v_positive(:decay_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
    end

    def kill_delay(args_h)
      args_h[:decay]
    end

  end

  class FXSlicer < FXInfo
    def name
      "Slicer"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_slicer"
    end

    def doc
      "Modulates the amplitude of the input signal with a specific control wave and phase duration. With the default pulse wave, slices the signal in and out, with the triangle wave, fades the signal in and out and with the saw wave, phases the signal in and then dramatically out. Control wave may be inverted with the arg invert_wave for more variety."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :phase => 0.25,
        :phase_slide => 0,
        :phase_slide_shape => 5,
        :phase_slide_curve => 0,
        :amp_min => 0,
        :amp_min_slide => 0,
        :amp_min_slide_shape => 5,
        :amp_min_slide_curve => 0,
        :amp_max => 1,
        :amp_max_slide => 0,
        :amp_max_slide_shape => 5,
        :amp_max_slide_curve => 0,
        :pulse_width => 0.5,
        :pulse_width_slide => 0,
        :pulse_width_slide_shape => 5,
        :pulse_width_slide_curve => 0,
        :phase_offset => 0,
        :wave => 1,
        :invert_wave => 0,
        :probability => 1,
        :seed => 0,
      }
    end

    def specific_arg_info
      {
        :probability =>
        {
          :doc => "Probability that a given slice will sound as a value between 0 and 1",
          :validations => [v_between_inclusive(:probability, 0, 1)],
          :modulatable => true
        },

        :seed =>
        {
          :doc => "Seed value for rand num generator used for probability test",
          :validations => [v_positive(:seed)],
          :modulatable => false
        },


        :phase =>
        {
          :doc => "The phase duration (in beats) of the slices",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => true
        },

        :phase_slide =>
        {
          :doc => "Slide time in beats between phase values",
          :validations => [v_positive(:phase_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :width =>
        {
          :doc => "The width of the slices - 0 - 1.",
          :validations => [v_between_exclusive(:width, 0, 1)],
          :modulatable => true
        },

        :width_slide =>
        {
          :doc => "Slide time in beats between width values",
          :validations => [v_positive(:width_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :phase_offset=>
        {
          :doc => "Initial phase offset.",
          :validations => [v_between_inclusive(:phase_offset, 0, 1)],
          :modulatable => false
        },

        :amp_slide =>
        {
          :doc => "The slide lag time for amplitude changes.",
          :validations => [v_positive(:amp_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :amp =>
        {
          :doc => "The amplitude of the resulting effect.",
          :validations => [v_positive(:amp)],
          :modulatable => true
        },

        :wave =>
        {
          :doc => "Control waveform used to modulate the amplitude. 0=saw, 1=pulse, 2=tri, 3=sine",
          :validations => [v_one_of(:wave, [0, 1, 2, 3])],
          :modulatable => true
        },

        :invert_wave =>
        {
          :doc => "Invert control waveform (i.e. flip it on the y axis). 0=uninverted wave, 1=inverted wave.",
          :validations => [v_one_of(:invert_wave, [0, 1])],
          :modulatable => true
        },

        :amp_min =>
        {
          :doc => "Minimum amplitude of the slicer",
          :validations => [v_positive(:amp_min)],
          :modulatable => true
        },

        :amp_min_slide =>
        {
          :doc => generic_slide_doc(:amp_min),
          :validations => [v_positive(:amp_min_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :amp_max =>
        {
          :doc => "Maximum amplitude of the slicer",
          :validations => [v_positive(:amp_max)],
          :modulatable => true
        },

        :amp_max_slide =>
        {
          :doc => generic_slide_doc(:amp_max),
          :validations => [v_positive(:amp_max_slide)],
          :modulatable => true,
          :bpm_scale => true
        }

      }
    end
  end

  class FXWobble < FXInfo
    def name
      "Wobble"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_wobble"
    end

    def doc
      "Versatile wobble FX. Will repeatedly modulate a range of filters (rlpf, rhpf) between two cutoff values using a range of control wave forms (saw, pulse, tri, sine). You may alter the phase duration of the wobble, and the resonance of the filter. Combines well with the dsaw synth for crazy dub wobbles. Cutoff value is at cutoff_min at the start of phase"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :phase => 0.5,
        :phase_slide => 0,
        :phase_slide_shape => 5,
        :phase_slide_curve => 0,
        :cutoff_min => 60,
        :cutoff_min_slide => 0,
        :cutoff_min_slide_shape => 5,
        :cutoff_min_slide_curve => 0,
        :cutoff_max => 120,
        :cutoff_max_slide => 0,
        :cutoff_max_slide_shape => 5,
        :cutoff_max_slide_curve => 0,
        :res => 0.8,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
        :phase_offset => 0,
        :wave => 0,
        :invert_wave => 0,
        :pulse_width => 0.5,
        :pulse_width_slide => 0,
        :pulse_width_slide_shape => 5,
        :pulse_width_slide_curve => 0,
        :filter => 0
      }
    end

    def specific_arg_info
      {

        :cutoff_min =>
        {
          :doc => "Minimum (MIDI) note filter will move to whilst wobbling. Choose a lower note for a higher range of movement. Full range of movement is the distance between cutoff_max and cutoff_min",
          :validations => [v_positive(:cutoff_min), v_less_than(:cutoff_min, 130)],
          :modulatable => true
        },

        :cutoff_min_slide =>
        {
          :doc => generic_slide_doc(:cutoff_min),
          :validations => [v_positive(:cutoff_min_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :cutoff_max =>
        {
          :doc => "Maximum (MIDI) note filter will move to whilst wobbling. Choose a higher note for a higher range of movement. Full range of movement is the distance between cutoff_max and cutoff_min",
          :validations => [v_positive(:cutoff_max), v_less_than(:cutoff_max, 130)],
          :modulatable => true
        },

        :cutoff_max_slide =>
        {
          :doc => generic_slide_doc(:cutoff_max),
          :validations => [v_positive(:cutoff_max_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :phase =>
        {
          :doc => "The phase duration (in beats) for filter modulation cycles",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => true
        },

        :pulse_width =>
        {
          :doc => "Only valid if wave is type pulse.",
          :validations => [v_positive(:pulse_width)],
          :modulatable => true
        },

        :pulse_width_slide =>
        {
          :doc => "Time in beats for pulse width to change. Only valid if wave is type pulse.",
          :validations => [v_positive(:pulse_width_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :wave =>
        {
          :doc => "Wave shape of wobble. Use 0 for saw wave, 1 for pulse, 2 for triangle wave and 3 for a sine wave.",
          :validations => [v_one_of(:wave, [0, 1, 2, 3])],
          :modulatable => true
        },

        :filter =>
        {
          :doc => "Filter used for wobble effect. Use 0 for a resonant low pass filter or 1 for a rsonant high pass filter",
          :validations => [v_one_of(:filter, [0, 1])],
          :modulatable => true
        }
      }
    end
  end



  class FXIXITechno < FXInfo
    def name
      "Techno from IXI Lang"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_ixi_techno"
    end

    def doc
      "Moving resonant low pass filter between min and max cutoffs. Great for sweeping effects across long synths or samples."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :phase => 4,
        :phase_slide => 0,
        :phase_slide_shape => 5,
        :phase_slide_curve => 0,
        :phase_offset => 0,
        :cutoff_min => 60,
        :cutoff_min_slide => 0,
        :cutoff_min_slide_shape => 5,
        :cutoff_min_slide_curve => 0,
        :cutoff_max => 120,
        :cutoff_max_slide => 0,
        :cutoff_max_slide_shape => 5,
        :cutoff_max_slide_curve => 0,
        :res => 0.8,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
      }
    end

    def specific_arg_info
      {
        :phase =>
        {
          :doc => "The phase duration (in beats) for filter modulation cycles",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => true
        },

        :phase_slide =>
        {
          :doc => generic_slide_doc(:phase),
          :validations => [v_positive(:phase_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :phase_offset =>
           {
          :doc => "Initial modulation phase offset (a value between 0 and 1).",
          :validations => [v_between_inclusive(:phase_offset, 0, 1)],
          :modulatable => false
        },

        :cutoff_min =>
        {
          :doc => "Minimum (MIDI) note filter will move to whilst wobbling. Choose a lower note for a higher range of movement. Full range of movement is the distance between cutoff_max and cutoff_min",
          :validations => [v_positive(:cutoff_min), v_less_than(:cutoff_min, 130)],
          :modulatable => true
        },

        :cutoff_min_slide =>
        {
          :doc => generic_slide_doc(:cutoff_min),
          :validations => [v_positive(:cutoff_min_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :cutoff_max =>
        {
          :doc => "Maximum (MIDI) note filter will move to whilst wobbling. Choose a higher note for a higher range of movement. Full range of movement is the distance between cutoff_max and cutoff_min",
          :validations => [v_positive(:cutoff_max), v_less_than(:cutoff_max, 130)],
          :modulatable => true
        },

        :cutoff_max_slide =>
        {
          :doc => generic_slide_doc(:cutoff_max),
          :validations => [v_positive(:cutoff_max_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :filter =>
        {
          :doc => "Filter used for wobble effect. Use 0 for a resonant low pass filter or 1 for a rsonant high pass filter",
          :validations => [v_one_of(:filter, [0, 1])],
          :modulatable => true
        }

      }
    end
  end


  class FXCompressor < FXInfo
    def name
      "Compressor"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_compressor"
    end

    def doc
      "Compresses the dynamic range of the incoming signal. Equivalent to automatically turning the amp down when the signal gets too loud and then back up again when it's quite. Useful for ensuring the containing signal doesn't overwhelm other aspects of the sound. Also a general purpose hard-knee dynamic range processor which can be tuned via the arguments to both expand and compress the signal."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :threshold => 0.2,
        :threshold_slide => 0,
        :threshold_slide_shape => 5,
        :threshold_slide_curve => 0,
        :clamp_time => 0.01,
        :clamp_time_slide => 0,
        :clamp_time_slide_shape => 5,
        :clamp_time_slide_curve => 0,
        :slope_above => 0.5,
        :slope_above_slide => 0,
        :slope_above_slide_shape => 5,
        :slope_above_slide_curve => 0,
        :slope_below => 1,
        :slope_below_slide => 0,
        :slope_below_slide_shape => 5,
        :slope_below_slide_curve => 0,
        :relax_time => 0.01,
        :relax_time_slide => 0,
        :relax_time_slide_shape => 5,
        :relax_time_slide_curve => 0,
      }
    end

    def specific_arg_info
      {

        :threshold =>
        {
          :doc => "threshold value determining the break point between slope_below and slope_above. ",
          :validations => [v_positive(:threshold)],
          :modulatable => true
        },

        :threshold_slide =>
        {
          :doc => generic_slide_doc(:threshold),
          :validations => [v_positive(:threshold_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :slope_below =>
        {
          :doc => "Slope of the amplitude curve below the threshold. A value of 1 means that the output of signals with amplitude below the threshold will be unaffected. Greater values will magnify and smaller values will attenuate the signal.",
          :validations => [],
          :modulatable => true
        },

        :slope_below_slide =>
        {
          :doc => generic_slide_doc(:slope_below),
          :validations => [v_positive(:slope_below_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :slope_above =>
        {
          :doc => "Slope of the amplitude curve above the threshold. A value of 1 means that the output of signals with amplitude above the threshold will be unaffected. Greater values will magnify and smaller values will attenuate the signal.",

          :validations => [],
          :modulatable => true
        },

        :slope_above_slide =>
        {
          :doc => generic_slide_doc(:slope_above),
          :validations => [v_positive(:slope_above_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :clamp_time =>
        {
          :doc => "Time taken for the amplitude adjustments to kick in fully (in seconds). This is usually pretty small (not much more than 10 milliseconds). Also known as the time of the attack phase",
          :validations => [v_positive(:clamp_time)],
          :modulatable => true
        },

        :clamp_time_slide =>
        {
          :doc => generic_slide_doc(:clamp_time),
          :validations => [v_positive(:clamp_time_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :relax_time =>
        {
          :doc => "Time taken for the amplitude adjustments to be released. Usually a little longer than clamp_time. If both times are too short, you can get some (possibly unwanted) artifacts. Also known as the time of the release phase.",
          :validations => [v_positive(:clamp_time)],
          :modulatable => true
        },

        :relax_time_slide =>
        {
          :doc => generic_slide_doc(:relax_time),
          :validations => [v_positive(:relax_time_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
    end
  end

  class FXOctaver < FXInfo
    def name
      "Octaver"
    end

    def introduced
      Version.new(2,2,0)
    end

    def synth_name
      "fx_octaver"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :oct1_amp => 1,
        :oct1_amp_slide => 0,
        :oct1_amp_slide_shape => 5,
        :oct1_amp_slide_curve => 0,
        :oct1_interval => 12,
        :oct1_interval_slide => 0,
        :oct1_interval_slide_shape => 5,
        :oct1_interval_slide_curve => 0,
        :oct2_amp => 1,
        :oct2_amp_slide => 0,
        :oct2_amp_slide_shape => 5,
        :oct2_amp_slide_curve => 0,
        :oct3_amp => 1,
        :oct3_amp_slide => 0,
        :oct3_amp_slide_shape => 5,
        :oct3_amp_slide_curve => 0
      }
    end

    def specific_arg_info
      {
        :oct1_amp =>
        {
          :doc => "Volume of the signal 1 octave above the input",
          :validations => [v_positive(:oct1_amp)],
          :modulatable => true
        },
        :oct2_amp =>
        {
          :doc => "Volume of the signal 1 octave below the input",
          :validations => [v_positive(:oct2_amp)],
          :modulatable => true
        },
        :oct3_amp =>
        {
          :doc => "Volume of the signal 2 octaves below the input",
          :validations => [v_positive(:oct3_amp)],
          :modulatable => true
        }
      }
    end

    def doc
      "This harmoniser adds three pitches based on the input sound. The first is the original sound transposed up an octave, the second is the original sound transposed down an octave and the third is the original sound transposed down two octaves.

The way the transpositions are done adds some distortion, particulary to the lower octaves, whilst the upper octave has a 'cheap' quality. This effect is often used in guitar effects pedals but it can work with other sounds too."
    end
  end

  class FXChorus < FXInfo
    def name
      "Chorus"
    end

    def introduced
      Version.new(2,2,0)
    end

    def synth_name
      "fx_chorus"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :phase => 0.25,
        :phase_slide => 0,
        :phase_slide_shape => 5,
        :phase_slide_curve => 0,
        :decay => 0.00001,
        :decay_slide => 0,
        :decay_slide_shape => 5,
        :decay_slide_curve => 0,
        :max_phase => 1
      }
    end

    def specific_arg_info
      {
        :max_phase =>
        {
          :doc => "The maximum phase duration in beats.",
          :validations => [v_positive_not_zero(:max_phase)],
          :modulatable => false
        },

        :phase =>
        {
          :doc => "The time between echoes in beats.",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => false
        },

        :phase_slide =>
        {
          :doc => "Slide time in beats between phase values",
          :validations => [v_positive(:phase_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :decay =>
        {
          :doc => "The time it takes for the echoes to fade away in beats.",
          :validations => [v_positive_not_zero(:decay)],
          :modulatable => true,
          :bpm_scale => true
        },

        :decay_slide =>
        {
          :doc => "Slide time in beats between decay times",
          :validations => [v_positive(:decay_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
    end

    def kill_delay(args_h)
      args_h[:decay]
    end

    def doc
      "Standard chorus with variable phase duration (time between echoes). A type of short echo that usually makes the sound \"thicker\". If you wish to have a phase duration longer than 2s, you need to specifiy the longest phase duration you'd like with the arg max_phase. Be warned, as with echo, chorus FX with very long phases can consume a lot of memory and take longer to initialise."
    end
  end

  class FXRingMod < FXInfo
    def name
      "Ring Modulator"
    end

    def introduced
      Version.new(2,3,0)
    end

    def synth_name
      "fx_ring_mod"
    end

    def arg_defaults
      {
        :freq => 30,
        :freq_slide => 0,
        :freq_slide_shape => 5,
        :freq_slide_curve => 0,
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :mod_amp => 1,
        :mod_amp_slide => 0,
        :mod_amp_slide_shape => 5,
        :mod_amp_slide_curve => 0,
      }
    end

    def specific_arg_info
      {
        :freq =>
        {
          :doc => "Frequency of the carrier signal (as a midi note).",
          :validations => [v_positive_not_zero(:freq)],
          :modulatable => true
        },

        :freq_slide =>
        {
          :doc => generic_slide_doc(:freq),
          :validations => [v_positive(:freq_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_amp =>
        {
          :doc => "Amplitude of the modulation",
          :validations => [v_positive(:mod_amp)],
          :modulatable => true
        }

      }
    end

    def doc
      "Attack of the Daleks! Ring mod is a classic effect often used on soundtracks to evoke robots or aliens as it sounds hollow or metallic. We take a 'carrier' signal (a sine wave controlled by the freq argument) and modulate its amplitude using the signal given inside the fx block. This produces a wide variety of sounds - the best way to learn is to experiment!"
    end
  end

  class FXVowel < FXInfo
    def name
      "Vowel Filter"
    end

    def introduced
      Version.new(2,6,0)
    end

    def synth_name
      "fx_vowel"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :vowel_sound => 0
      }
    end

    def specific_arg_info
      {
        :vowel_sound =>
        {
          :doc => "A,e,i,o or u",
          :validations => [v_one_of(:vowel_sound, [0, 1, 2, 3, 4])],
          :modulatable => true
        },

      }
    end

    def doc
      "Filter the input to mimic the sound of a soprano voice singing vowels"
    end
  end

  class FXBPF < FXInfo
    def name
      "Band Pass Filter"
    end

    def introduced
      Version.new(2,3,0)
    end

    def synth_name
      "fx_bpf"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :centre => 100,
        :centre_slide => 0,
        :centre_slide_shape => 5,
        :centre_slide_curve => 0

      }
    end

    def specific_arg_info
      {
        :centre =>
        {
          :doc => "Centre frequency for the filter as a MIDI note. ",
          :validations => [v_greater_than_oet(:centre, 0)],
          :modulatable => true
        },

      }
    end

    def doc
      "Combines low pass and high pass filters to only allow a 'band' of frequencies through. If the band is very narrow (a low res value like 0.0001) then the BPF will reduce the original sound, almost down to a single frequency (controlled by the centre argument).

With higher values for res we can simulate other filters e.g. telephone lines, by cutting off low and high frequencies."
    end
  end

  class FXRBPF < FXBPF
    def name
      "Resonant Band Pass Filter"
    end

    def introduced
      Version.new(2,3,0)
    end

    def synth_name
      "fx_rbpf"
    end

    def arg_defaults
      super.merge({
        :res => 0.5,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0
      })
    end

    def doc
      "Like the Band Pass Filter but with a resonance (slight volume boost) around the target frequency. This can produce an interesting whistling effect, especially when used with smaller values for the res argument."
    end
  end

    class FXNBPF < FXBPF
    def name
      "Normalised Band Pass Filter"
    end

    def introduced
      Version.new(2,3,0)
    end

    def synth_name
      "fx_nbpf"
    end

    def doc
      "Like the Band Pass Filter but normalized. The normalizer is useful here as some volume is lost when filtering the original signal."
    end
  end



  class FXNRBPF < FXRBPF
    def name
      "Normalised Resonant Band Pass Filter"
    end

    def introduced
      Version.new(2,3,0)
    end

    def synth_name
      "fx_nrbpf"
    end

    def doc
      "Like the Band Pass Filter but normalized, with a resonance (slight volume boost) around the target frequency. This can produce an interesting whistling effect, especially when used with smaller values for the res argument.

The normalizer is useful here as some volume is lost when filtering the original signal."
    end
  end

  class FXRLPF < FXInfo
    def name
      "Resonant Low Pass Filter"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_rlpf"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :res => 0.5,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
      }
    end

    def specific_arg_info
      {


      }
    end

    def doc
      "Dampens the parts of the signal that are above than the cutoff point (typically the crunchy fizzy harmonic overtones) and keeps the lower parts (typicaly the bass/mid of the sound). behaviour, The resonant part of the resonant low pass filter emphasises/resonates the frequencies around the cutoff point. The amount of emphasis is controlled by the res param with a lower res resulting in greater resonance. High amounts of resonance (rq ~0) can create a whistling sound around the cutoff frequency.

Choose a higher cutoff to keep more of the high frequences/treble of the sound and a lower cutoff to make the sound more dull and only keep the bass."
    end
  end

  class FXNormRLPF < FXRLPF
    def name
      "Normalised Resonant Low Pass Filter"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_nrlpf"
    end
  end

  class FXRHPF < FXInfo
    def name
      "Resonant High Pass Filter"
    end

    def doc
      "Dampens the parts of the signal that are lower than the cutoff point (typicaly the bass of the sound) and keeps the higher parts (typically the crunchy fizzy harmonic overtones). The resonant part of the resonant low pass filter emphasises/resonates the frequencies around the cutoff point. The amount of emphasis is controlled by the res param with a lower res resulting in greater resonance. High amounts of resonance (rq ~0) can create a whistling sound around the cutoff frequency.

Choose a lower cutoff to keep more of the bass/mid and a higher cutoff to make the sound more light and crispy. "
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_rhpf"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
        :res => 0.5,
        :res_slide => 0,
        :res_slide_shape => 5,
        :res_slide_curve => 0,
      }
    end

    def specific_arg_info
      {


      }
    end
  end

  class FXNormRHPF < FXRLPF
    def name
      "Normalised Resonant High Pass Filter"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_nrhpf"
    end

      "A resonant high pass filter chained to a normaliser. Ensures that the signal is both filtered by a standard high pass filter and then normalised to ensure the amplitude of the final output is constant. A high pass filter will reduce the amplitude of the resulting signal (as some of the sound has been filtered out) the normaliser can compensate for this loss (although will also have the side effect of flattening all dynamics). See doc for hpf."
  end

  class FXLPF < FXInfo
    def name
      "Low Pass Filter"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_lpf"
    end

    def doc
      "Dampens the parts of the signal that are above than the cutoff point(typically the crunchy fizzy harmonic overtones) and keeps the lower parts (typicaly the bass/mid of the sound). Choose a higher cutoff to keep more of the high frequences/treble of the sound and a lower cutoff to make the sound more dull and only keep the bass."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
      }
    end

    def specific_arg_info
      {


      }
    end
  end

  class FXNormLPF < FXLPF
    def name
      "Normalised Low Pass Filter."
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_nlpf"
    end

    def doc
      "A low pass filter chained to a normaliser. Ensures that the signal is both filtered by a standard low pass filter and then normalised to ensure the amplitude of the final output is constant. A low pass filter will reduce the amplitude of the resulting signal (as some of the sound has been filtered out) the normaliser can compensate for this loss (although will also have the side effect of flattening all dynamics). See doc for lpf."
    end
  end

  class FXHPF < FXInfo
    def name
      "High Pass Filter"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_hpf"
    end

    def doc
      "Dampens the parts of the signal that are lower than the cutoff point (typicaly the bass of the sound) and keeps the higher parts (typically the crunchy fizzy harmonic overtones). Choose a lower cutoff to keep more of the bass/mid and a higher cutoff to make the sound more light and crispy. "
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :cutoff => 100,
        :cutoff_slide => 0,
        :cutoff_slide_shape => 5,
        :cutoff_slide_curve => 0,
      }
    end
  end

  class FXNormHPF < FXRLPF
    def name
      "Normalised High Pass Filter"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_nhpf"
    end

    def doc
      "A high pass filter chained to a normaliser. Ensures that the signal is both filtered by a standard high pass filter and then normalised to ensure the amplitude of the final output is constant. A high pass filter will reduce the amplitude of the resulting signal (as some of the sound has been filtered out) the normaliser can compensate for this loss (although will also have the side effect of flattening all dynamics). See doc for hpf."
    end
  end

  class FXNormaliser < FXInfo
    def name
      "Normaliser"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_normaliser"
    end

    def doc
      "Raise or lower amplitude of sound to a specified level. Evens out the amplitude of incoming sound across the frequency spectrum by flattening all dynamics."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :level => 1,
        :level_slide => 0,
        :level_slide_shape => 5,
        :level_slide_curve => 0
      }
    end

    def specific_arg_info
      {
        :level =>
        {
          :doc => "The peak output amplitude level to which to normalise the in",
          :validations => [v_greater_than_oet(:level, 0)],
          :modulatable => true
        },

        :level_slide =>
        {
          :doc => generic_slide_doc(:level),
          :validations => [v_positive(:level_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
    end
  end

  class FXPitchShift < FXInfo
    def name
      "Pitch shift"
    end

    def introduced
      Version.new(2,5,0)
    end

    def synth_name
      "fx_pitch_shift"
    end

    def trigger_with_logical_clock?
      :t_minus_delta
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :window_size => 0.2,
        :window_size_slide => 0,
        :window_size_slide_shape => 1,
        :window_size_slide_curve => 0,
        :pitch => 0,
        :pitch_slide => 0,
        :pitch_slide_shape => 1,
        :pitch_slide_curve => 0,
        :pitch_dis => 0.0,
        :pitch_dis_slide => 0,
        :pitch_dis_slide_shape => 1,
        :pitch_dis_slide_curve => 0,
        :time_dis => 0.0,
        :time_dis_slide => 0,
        :time_dis_slide_shape => 1,
        :time_dis_slide_curve => 0,
      }
    end

    def specific_arg_info
      {
        :pitch =>
        {
          :doc => "Pitch adjustment in semitones. 1 is up a semitone, 12 is up an octave, -12 is down an octave etc. Maximum upper limit of 24 (up 2 octaves). Lower limit of -72 (down 6 octaves). Decimal numbers can be used for fine tuning.",
          :validations => [v_greater_than_oet(:pitch, -72), v_less_than_oet(:pitch, 24)],
          :modulatable => true
        },
        :window_size =>
        {
          :doc => "Pitch shift works by chopping the input into tiny slices, then playing these slices at a higher or lower rate. If we make the slices small enough and overlap them, it sounds like the original sound with the pitch changed.

The window_size is the length of the slices and is measured in seconds. It needs to be around 0.2 (200ms) or greater for pitched sounds like guitar or bass, and needs to be around 0.02 (20ms) or lower for percussive sounds like drum loops. You can experiment with this to get the best sound for your input.",
          :validations => [v_greater_than(:window_size, 0.00005)],
          :modulatable => true
        },
        :pitch_dis =>
        {
          :doc => "Pitch dispersion - how much random variation in pitch to add. Using a low value like 0.001 can help to \"soften up\" the metallic sounds, especially on drum loops. To be really technical, pitch_dispersion is the maximum random deviation of the pitch from the pitch ratio (which is set by the pitch param)",
          :validations => [v_greater_than_oet(:pitch_dis, 0)],
          :modulatable => true
        },
        :time_dis =>
        {
          :doc => "Time dispersion - how much random delay before playing each grain (measured in seconds). Again, low values here like 0.001 can help to soften up metallic sounds introduced by the effect. Large values are also fun as they can make soundscapes and textures from the input, although you will most likely lose the rhythm of the original. NB - This won't have an effect if it's larger than window_size. ",
          :validations => [v_greater_than_oet(:time_dis, 0)],
          :modulatable => true
        },

      }
    end

    def doc
      "Changes the pitch of a signal without affecting tempo. Does this mainly through the pitch parameter which takes a midi number to transpose by. You can also play with the other params to produce some interesting textures and sounds."
    end
  end

  class FXDistortion < FXInfo
    def name
      "Distortion"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_distortion"
    end

    def doc
      "Distorts the signal reducing clarity in favour of raw crunchy noise."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :distort => 0.5,
        :distort_slide => 0,
        :distort_slide_shape => 5,
        :distort_slide_curve => 0,
      }
    end

    def specific_arg_info
      {
        :distort =>
        {
          :doc => "Amount of distortion to be applied (as a value between 0 ad 1)",
          :validations => [v_greater_than_oet(:distort, 0), v_less_than(:distort, 1)],
          :modulatable => true
        },

        :distort_slide =>
        {
          :doc => generic_slide_doc(:distort),
          :validations => [v_positive(:distort_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
      end
  end



  class FXPan < FXInfo
    def name
      "Pan"
    end

    def introduced
      Version.new(2,0,0)
    end

    def synth_name
      "fx_pan"
    end

    def doc
      "Specify where in the stereo field the sound should be heard. A value of -1 for pan will put the sound in the left speaker, a value of 1 will put the sound in the right speaker and values in between will shift the sound accordingly."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :pan => 0,
        :pan_slide => 0,
        :pan_slide_shape => 5,
        :pan_slide_curve => 0,
      }
    end
  end

    class FXFlanger < FXInfo
    def name
      "Flanger"
    end

    def introduced
      Version.new(2,3,0)
    end

    def synth_name
      "fx_flanger"
    end

    def doc
      "Mix the incoming signal with a copy of itself which has a rate modulating faster and slower than the original.  Creates a swirling/whooshing effect."
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :amp_slide_shape => 5,
        :amp_slide_curve => 0,
        :mix => 1,
        :mix_slide => 0,
        :mix_slide_shape => 5,
        :mix_slide_curve => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :pre_amp_slide_shape => 5,
        :pre_amp_slide_curve => 0,
        :phase => 4,
        :phase_slide => 0,
        :phase_slide_shape => 5,
        :phase_slide_curve => 0,
        :phase_offset => 0,
        :wave => 4,
        :invert_wave => 0,
        :stereo_invert_wave => 0,
        :delay => 5,
        :delay_slide => 0,
        :delay_slide_shape => 5,
        :delay_slide_curve => 0,
        :max_delay => 20,
        :depth => 5,
        :depth_slide => 0,
        :depth_slide_shape => 5,
        :depth_slide_curve => 0,
        :decay => 2,
        :decay_slide => 0,
        :decay_slide_shape => 5,
        :decay_slide_curve => 0,
        :feedback => 0,
        :feedback_slide => 0,
        :feedback_slide_shape => 5,
        :feedback_slide_curve => 0,
        :invert_flange => 0
      }
    end

    def specific_arg_info
      {


        :phase =>
        {
          :doc => "Phase duration in beats of flanger modulation.",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => true
        },

        :wave =>
        {
          :doc => "Wave type - 0 saw, 1 pulse, 2 triangle, 3 sine, 4 cubic. Different waves will produce different flanging modulation effects.",
          :validations => [v_one_of(:wave, [0, 1, 2, 3, 4])],
          :modulatable => true
        },

        :invert_wave =>
        {
          :doc => "Invert flanger control waveform (i.e. flip it on the y axis). 0=uninverted wave, 1=inverted wave.",
          :validations => [v_one_of(:invert_wave, [0, 1])],
          :modulatable => true
        },

        :stereo_invert_wave =>
        {
          :doc => "Make the flanger control waveform in the left ear an inversion of the control waveform in the right ear. 0=uninverted wave, 1=inverted wave. This happens after the standard wave inversion with param :invert_wave.",
          :validations => [v_one_of(:stereo_invert_wave, [0, 1])],
          :modulatable => true
        },

        :delay =>
        {
          :doc => "Amount of delay time between original and flanged version of audio.",
          :modulatable => true
        },

        :max_delay =>
        {
          :doc => "Max delay time. Used to set internal buffer size.",
          :validations => [v_positive(:max_delay)],
          :modulatable => false
        },

        :depth =>
        {
          :doc => "Flange depth - greater depths produce a more prominent effect.",
          :modulatable => true
        },

        :decay =>
        {
          :doc => "Flange decay time in ms",
          :validations => [v_positive(:decay)],
          :modulatable => true
        },

        :feedback =>
        {
          :doc => "Amount of feedback.",
          :validations => [v_positive(:feedback)],
          :modulatable => true
        },

        :invert_flange =>
        {
          :doc => "Invert flanger signal. 0=no inversion, 1=inverted signal.",
          :validations => [v_one_of(:invert_flange, [0, 1])],
          :modulatable => true
        }

      }
      end
  end

  class BaseInfo

    @@grouped_samples =
      {
      :drum => {
        :desc => "Drum Sounds",
        :prefix => "drum_",
        :samples => [
          :drum_heavy_kick,
          :drum_tom_mid_soft,
          :drum_tom_mid_hard,
          :drum_tom_lo_soft,
          :drum_tom_lo_hard,
          :drum_tom_hi_soft,
          :drum_tom_hi_hard,
          :drum_splash_soft,
          :drum_splash_hard,
          :drum_snare_soft,
          :drum_snare_hard,
          :drum_cymbal_soft,
          :drum_cymbal_hard,
          :drum_cymbal_open,
          :drum_cymbal_closed,
          :drum_cymbal_pedal,
          :drum_bass_soft,
          :drum_bass_hard]},

      :elec => {
        :desc => "Electric Sounds",
        :prefix => "elec_",
        :samples => [
          :elec_triangle,
          :elec_snare,
          :elec_lo_snare,
          :elec_hi_snare,
          :elec_mid_snare,
          :elec_cymbal,
          :elec_soft_kick,
          :elec_filt_snare,
          :elec_fuzz_tom,
          :elec_chime,
          :elec_bong,
          :elec_twang,
          :elec_wood,
          :elec_pop,
          :elec_beep,
          :elec_blip,
          :elec_blip2,
          :elec_ping,
          :elec_bell,
          :elec_flip,
          :elec_tick,
          :elec_hollow_kick,
          :elec_twip,
          :elec_plip,
          :elec_blup]},

      :guit => {
        :desc => "Sounds featuring guitars",
        :prefix => "guit_",
        :samples => [
          :guit_harmonics,
          :guit_e_fifths,
          :guit_e_slide,
          :guit_em9]},

      :misc => {
        :desc => "Miscellaneous Sounds",
        :prefix => "misc_",
        :samples => [
          :misc_burp,
          :misc_rand_noise]},

      :perc => {
        :desc => "Percussive Sounds",
        :prefix => "perc_",
        :samples => [
          :perc_bell,
          :perc_snap,
          :perc_snap2]},

      :ambi => {
        :desc => "Ambient Sounds",
        :prefix => "ambi_",
        :samples => [
          :ambi_soft_buzz,
          :ambi_swoosh,
          :ambi_drone,
          :ambi_glass_hum,
          :ambi_glass_rub,
          :ambi_haunted_hum,
          :ambi_piano,
          :ambi_lunar_land,
          :ambi_dark_woosh,
          :ambi_choir]},

      :bass => {
        :desc => "Bass Sounds",
        :prefix => "bass_",
        :samples => [
          :bass_hit_c,
          :bass_hard_c,
          :bass_thick_c,
          :bass_drop_c,
          :bass_woodsy_c,
          :bass_voxy_c,
          :bass_voxy_hit_c,
          :bass_dnb_f]},

      :snares => {
        :desc => "Snare Drums",
        :prefix => "ns_",
        :samples => [
          :sn_dub,
          :sn_dolf,
          :sn_zome]},

      :bass_drums => {
        :desc => "Bass Drums",
        :prefix => "bd_",
        :samples => [
          :bd_ada,
          :bd_pure,
          :bd_808,
          :bd_zum,
          :bd_gas,
          :bd_sone,
          :bd_haus,
          :bd_zome,
          :bd_boom,
          :bd_klub,
          :bd_fat,
          :bd_tek]},

      :loop => {
        :desc => "Sounds for Looping",
        :prefix => "loop_",
        :samples => [
          :loop_industrial,
          :loop_compus,
          :loop_amen,
          :loop_amen_full,
          :loop_garzul,
          :loop_mika]}}

    @@all_samples = (@@grouped_samples.values.reduce([]) {|s, el| s << el[:samples]}).flatten

    @@synth_infos =
      {
      :dull_bell => DullBell.new,
      :pretty_bell => PrettyBell.new,
      :beep => Beep.new,
      :sine => Beep.new,
      :saw => Saw.new,
      :pulse => Pulse.new,
      :square => Square.new,
      :tri => Tri.new,
      :dsaw => DSaw.new,
      :fm => FM.new,
      :mod_fm => ModFM.new,
      :mod_saw => ModSaw.new,
      :mod_dsaw => ModDSaw.new,
      :mod_sine => ModSine.new,
      :mod_beep => ModSine.new,
      :mod_tri => ModTri.new,
      :mod_pulse => ModPulse.new,
      :tb303 => TB303.new,
      :supersaw => Supersaw.new,
      :hoover => Hoover.new,
      :prophet => Prophet.new,
      :zawa => Zawa.new,
      :dark_ambience => DarkAmbience.new,
      :growl => Growl.new,
      :hollow => Hollow.new,
#      :dark_sea_horn => DarkSeaHorn.new,
#      :singer        => Singer.new,
      :mono_player => MonoPlayer.new,
      :stereo_player => StereoPlayer.new,

      :sound_in => SoundIn.new,
      :noise => Noise.new,
      :pnoise => PNoise.new,
      :bnoise => BNoise.new,
      :gnoise => GNoise.new,
      :cnoise => CNoise.new,

      :basic_mono_player => BasicMonoPlayer.new,
      :basic_stereo_player => BasicStereoPlayer.new,
      :basic_mixer => BasicMixer.new,

      :fx_bitcrusher => FXBitcrusher.new,
      :fx_krush => FXKrush.new,
      :fx_reverb => FXReverb.new,
      :fx_replace_reverb => FXReverb.new,
      :fx_level => FXLevel.new,
      :fx_replace_level => FXLevel.new,
      :fx_echo => FXEcho.new,
      :fx_replace_echo => FXEcho.new,
      :fx_slicer => FXSlicer.new,
      :fx_replace_slicer => FXSlicer.new,
      :fx_wobble => FXWobble.new,
      :fx_replace_wobble => FXWobble.new,
      :fx_ixi_techno => FXIXITechno.new,
      :fx_replace_ixi_techno => FXIXITechno.new,
      :fx_compressor => FXCompressor.new,
      :fx_replace_compressor => FXCompressor.new,
      :fx_rlpf => FXRLPF.new,
      :fx_replace_rlpf => FXRLPF.new,
      :fx_nrlpf => FXNormRLPF.new,
      :fx_replace_nrlpf => FXNormRLPF.new,
      :fx_rhpf => FXRHPF.new,
      :fx_replace_rhpf => FXRHPF.new,
      :fx_nrhpf => FXNormRHPF.new,
      :fx_replace_nrhpf => FXNormRHPF.new,
      :fx_hpf => FXHPF.new,
      :fx_replace_hpf => FXHPF.new,
      :fx_nhpf => FXNormHPF.new,
      :fx_replace_nhpf => FXNormHPF.new,
      :fx_lpf => FXLPF.new,
      :fx_replace_lpf => FXLPF.new,
      :fx_nlpf => FXNormLPF.new,
      :fx_replace_nlpf => FXNormLPF.new,
      :fx_normaliser => FXNormaliser.new,
      :fx_replace_normaliser => FXNormaliser.new,
      :fx_distortion => FXDistortion.new,
      :fx_replace_distortion => FXDistortion.new,
      :fx_pan => FXPan.new,
      :fx_replace_pan => FXPan.new,
      :fx_vowel => FXVowel.new,
      :fx_bpf => FXBPF.new,
      :fx_nbpf => FXNBPF.new,
      :fx_rbpf => FXRBPF.new,
      :fx_nrbpf => FXNRBPF.new,
      :fx_pitch_shift => FXPitchShift.new,
      :fx_ring_mod => FXRingMod.new,
      #:fx_chorus => FXChorus.new,
      #:fx_harmoniser => FXHarmoniser.new,
      :fx_flanger => FXFlanger.new
    }

    def self.get_info(synth_name)
      @@synth_infos[synth_name.to_sym]
    end

    def self.get_all
      @@synth_infos
    end

    def self.grouped_samples
      @@grouped_samples
    end

    def self.all_samples
      @@all_samples
    end

    def self.info_doc_html_map(klass)
      key_mod = nil
      res = {}

      max_len =  0
      get_all.each do |k, v|
        next unless v.is_a? klass
        next if (klass == FXInfo) && (k.to_s.include? 'replace_')
        next if v.is_a? StudioInfo
        if klass == SynthInfo
          max_len = k.to_s.size if k.to_s.size > max_len
        else
          max_len = (k.to_s.size - 3) if (k.to_s.size - 3) > max_len
        end
      end

      get_all.each do |k, v|
        next unless v.is_a? klass
        next if (klass == FXInfo) && (k.to_s.include? 'replace_')

        next if v.is_a? StudioInfo
        doc = ""

        doc << "<head>\n<link rel=\"stylesheet\" type=\"text/css\" href=\"qrc:///html/styles.css\"/>\n</head>\n\n<body class=\"manual\">\n\n"
        doc << "<h1>" << v.name << "</h1>\n\n"

        doc << "<p><table class=\"arguments\"><tr>\n"
        cnt = 0
        v.arg_info.each do |ak, av|
          doc << "</tr><tr>" if (cnt > 0) and cnt % 6 == 0
          td_class = cnt.even? ? "even" : "odd"
          doc << "<td class=\"#{td_class}\"><a href=\"##{ak}\">#{ak}:</a></td>\n"
          doc << "<td class=\"#{td_class}\">#{av[:default]}</td>\n"
          cnt += 1
        end
        doc << "</tr></table></p>\n\n"

        doc << "<p class=\"usage\"><code><pre>"
        if klass == SynthInfo
          safe_k = k
          doc << "use_synth <span class=\"symbol\">:#{safe_k}</span>"
        else
          safe_k = k.to_s[3..-1]
          doc << "with_fx <span class=\"symbol\">:#{safe_k}</span> <span class=\"keyword\">do</span>\n"
          doc << "  play <span class=\"number\">50</span>\n"
          doc << "<span class=\"keyword\">end</span>"
        end
        doc << "</pre></code></p>\n"

        doc << Kramdown::Document.new(v.doc).to_html << "\n"

        doc << "<p class=\"introduced\">"
        doc << "Introduced in " << v.introduced.to_s << "</p>\n\n"

        doc << "<h2>Parameters</h2>\n"

        doc << "<p><table class=\"details\">\n"

        cnt = 0
        any_slidable = false
        v.arg_info.each do |ak, av|
          td_class = cnt.even? ? "even" : "odd"
          doc << "<a name=\"#{ak}\"></a>\n"
          doc << "<tr>\n"
          doc << " <td class=\"#{td_class} key\">#{ak}:</td>\n"
          doc << " <td class=\"#{td_class}\">\n"
          docstring = av[:doc] || 'write me'
          doc <<  Kramdown::Document.new(docstring).to_html
          doc << "  <p class=\"properties\">\n"
          doc << "   Default: #{av[:default]}\n"
          doc << "   <br/>#{av[:constraints].join(",").capitalize}\n" unless av[:constraints].empty?
          doc << "   <br/>#{av[:modulatable] ? "May be changed whilst playing" : "Can not be changed once set"}\n"
          doc << "   <br/><a href=\"#slide\">Has slide parameters to shape changes</a>\n" if av[:slidable]
          doc << "   <br/>Scaled with current BPM value\n" if av[:bpm_scale]
          doc << "  </p>\n"
          doc << " </td>\n"
          doc << "</tr>\n"
          any_slidable = true if av[:slidable]
          cnt += 1
        end
        doc << "</table></p>\n"

        if any_slidable then
          doc << "<a name=slide></a>\n"
          doc << "<h2>Slide Parameters</h2>\n"
          doc << "<p>Any parameter that is slidable has three additional parameters named _slide, _slide_curve, and _slide_shape.  For example, 'amp' is slidable, so you can also set amp_slide, amp_slide_curve, and amp_slide_shape with the following effects:</p>\n"
          slide_args = {
            :_slide => {:default => 0, :doc=>v.generic_slide_doc('parameter')},
            :_slide_shape => {:default=>5, :doc=>v.generic_slide_shape_doc('parameter')},
            :_slide_curve => {:default=>0, :doc=>v.generic_slide_curve_doc('parameter')}
          }

          # table for slide parameters
          doc << "<p><table class=\"details\">\n"

          cnt = 0
          slide_args.each do |ak, av|
            td_class = cnt.even? ? "even" : "odd"
            doc << "<tr>\n"
            doc << " <td class=\"#{td_class} key\">#{ak}:</td>\n"
            doc << " <td class=\"#{td_class}\">\n"
            doc << "  <p>#{av[:doc] || 'write me'}</p>\n"
            doc << "  <p class=\"properties\">\n"
            doc << "   Default: #{av[:default]}\n"
            doc << "  </p>\n"
            doc << " </td>\n"
            doc << "</tr>\n"
            cnt += 1
          end
          doc << "</table></p>\n"
        end # any_slidable

        doc << "</body>\n"

        res["#{safe_k}"] = doc
      end
      res
    end

    def self.info_doc_markdown(name, klass, key_mod=nil)
      res = "# #{name}\n\n"

      get_all.each do |k, v|
        next unless v.is_a? klass
        snake_case = v.name.downcase.gsub(/ /, "-")
        res << "* [#{v.name}](##{snake_case})\n"
      end
      res << "\n"
      get_all.each do |k, v|
        next unless v.is_a? klass
        res << "## " << v.name << "\n\n"
        res << "### Key:\n"
        mk = key_mod ? key_mod.call(k) : k
        res << "  :#{mk}\n\n"
        res << "### Doc:\n"
        res << "  " << v.doc << "\n\n"
        res << "### Arguments:" "\n"
        v.arg_info.each do |ak, av|
          res << "  * #{ak}:\n"
          res << "    - doc: #{av[:doc] || 'write me'}\n"
          res << "    - default: #{av[:default]}\n"
          res << "    - constraints: #{av[:constraints].empty? ? "none" : av[:constraints].join(",")}\n"
          res << "    - #{av[:modulatable] ? "May be changed whilst playing" : "Can not be changed once set"}\n"
          res << "    - Scaled with current BPM value\n" if av[:bpm_scale]
          res << "    - Has slide parameters for shaping changes\n" if av[:slidable]
        end
        res << "\n\n"

      end
      res
    end

    def self.synth_doc_html_map
      info_doc_html_map(SynthInfo)
    end

    def self.fx_doc_html_map
      info_doc_html_map(FXInfo)
    end

    def self.synth_doc_markdown
      info_doc_markdown("Synths", SynthInfo)
    end

    def self.fx_doc_markdown
      info_doc_markdown("FX", FXInfo, lambda{|k| k.to_s[3..-1]})
    end

    def self.samples_doc_html_map
      res = {}

      grouped_samples.each do |k, v|
      cnt = 0
        cnt = 0
        doc = ""
        doc << "<head>\n<link rel=\"stylesheet\" type=\"text/css\" href=\"qrc:///html/styles.css\"/>\n</head>\n\n<body class=\"manual\">\n\n"
        doc << "<h1>" << v[:desc] << "</h1>\n"
        doc << "<p><table class=\"arguments\"><tr>\n"
        StereoPlayer.new.arg_info.each do |ak, av|
          doc << "</tr><tr>" if (cnt > 0) and cnt % 6 == 0
          td_class = cnt.even? ? "even" : "odd"
          doc << "<td class=\"#{td_class}\"><a href=\"##{ak}\">#{ak}:</a></td>\n"
          doc << "<td class=\"#{td_class}\">#{av[:default]}</td>\n"
          cnt += 1
        end
        doc << "</tr></table></p>\n"

        doc << "<p class=\"usage\"><code><pre>"

        v[:samples].each do |s|
          doc << "sample <span class=\"symbol\">:#{s}</span>\n"
        end
        doc << "</pre></code></p>\n"

        doc << "<p><table class=\"details\">\n"

        cnt = 0
        StereoPlayer.new.arg_info.each do |ak, av|
          td_class = cnt.even? ? "even" : "odd"
          doc << "<a name=\"#{ak}\"></a>\n"
          doc << "<tr>\n"
          doc << " <td class=\"#{td_class} key\">#{ak}:</td>\n"
          doc << " <td class=\"#{td_class}\">\n"
          doc << "  <p>#{av[:doc] || 'write me'}</p>\n"
          doc << "  <p class=\"properties\">\n"
          doc << "   Default: #{av[:default]}\n"
          doc << "   <br/>#{av[:constraints].join(",")}\n" unless av[:constraints].empty?
          doc << "   <br/>May be changed whilst playing\n" if av[:slidable]
          doc << "   <br/>Scaled with current BPM value\n" if av[:bpm_scale]
          doc << "  </p>\n"
          doc << " </td>\n"
          doc << "</tr>\n"
          cnt += 1
        end
        doc << "</table></p>\n"
        doc << "</body>\n"

        res[v[:desc]] = doc
      end
      res
    end

    def self.samples_doc_markdown
      res = "# Samples\n\n"
      grouped_samples.values.each do |info|
        res << "## #{info[:desc]}\n"
        info[:samples].each do |s|
          res << "* :#{s}\n"
        end
        res << "\n\n"

      end
      res
    end
  end
end
