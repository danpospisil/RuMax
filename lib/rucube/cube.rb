#!/usr/bin/env ruby
require 'socket'
require 'rucube/network'
require 'rucube/messages'

module RuCube
  class Cube
    # your code goes here
    def initialize(ip, port, network)
      @ip = ip
      @port = port
      @connected = false
      @network = network
      @socket = nil
    end

    def connect
      if @connected == true
        print('Already connected!')
        return
      end
      @socket = @network.create_socket(@ip, @port)
      @connected = true
      @network.receive(@socket)
    end

    def disconnect
      if @connected == true
        @socket.close
        @socket = nil
        @connected = false
      end
    end

    def set_temps(rf_addr, room_number, comfort, eco, min, max, offset, window_open, window_open_duration)
      payload = SetTemperature.new(rf_addr, room_number, comfort, eco, min, max, offset, window_open, window_open_duration).prepare_payload
      @network.send_message(@socket, payload)
    end

    def set_mode(rf_addr, room_number, mode, params)
      payload = SetModeAndTemperature.new(rf_addr, room_number, mode, params).prepare_payload
      @network.send_message(@socket, payload)
    end
  end
end
