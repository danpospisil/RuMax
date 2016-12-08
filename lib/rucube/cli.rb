#!/usr/bin/env ruby
require 'trollop'
require 'rucube/cube'
require 'rucube/network'

module RuCube
  class CLI
    def initialize(_args)
      @network = Network.new(true)
      opts = Trollop::options do
        opt :discover, 'Find a Cube on network'
        opt :connect, 'Connect to a Cube'
        opt :ip, 'Address of the Cube', type: :string
        opt :port, 'Port of the Cube', type: :int, default: 62_910
        opt :manual, 'Set manual mode and set temperature', type: :int
        opt :temperature, 'Set temperature for manual mode', default: 15
        opt :auto, 'Set automatic mode', type: :int
        opt :max_temp, 'Set max temp', type: :int
        opt :rf_addr, 'Set rf address', type: :string
      end
      process_input(opts)
    end

    def process_input(opts)
      @network.discover if opts[:discover] == true
      cube = Cube.new(opts[:ip], opts[:port], @network) if opts[:discover] != true
      if opts[:connect] == true
        if opts[:ip].nil?
          print('Error, -i command not specified')
          return
        end
        cube.connect
      elsif opts[:discover] != true
        print('Error, -c command not specified')
        return
      end
      if opts[:max_temp_given] == true
        if opts[:rf_addr].nil?
          print('Error, -r command not specified')
          return
        end
        cube.set_temps(opts[:rf_addr], 1, 15, 15, 15, opts[:max_temp], 0, 12, 1)
      end
      if opts[:manual_given] == true
        if opts[:rf_addr].nil?
          print('Error, -r command not specified')
          return
        end
        cube.set_mode(opts[:rf_addr], 1, 'ModeManual', { 'temperature' => opts[:manual] })
      end
      if opts[:auto_given] == true
        if opts[:rf_addr].nil?
          print('Error, -r command not specified')
          return
        end
        cube.set_mode(opts[:rf_addr], 1, 'ModeAuto', { 'temperature' => opts[:auto] })
      end
    end
  end
end
