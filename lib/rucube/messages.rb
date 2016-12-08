#!/usr/bin/env ruby
require 'base64'

module RuCube
  class BaseMessage
    @@types = {
      'TemperatureAndMode' => '000440000000',
      'Program' => '000410000000',
      'Temperatures' => '000011000000',
      'ValveConfig' => '000412000000'
    }

    def hex_to_raw_bytes(data)
      todecode = data.length.even? ? data : '0' + data
      todecode.scan(/../).map(&:hex).map(&:chr).join
    end

    def to_raw_bytes(data)
      data.to_i.chr
    end

    def initialize(rf_addr, room_number, type)
      @rf_addr = rf_addr
      @room_number = room_number
      @type = type
    end

    def prepare_base_payload
      payload = ''
      payload += hex_to_raw_bytes(@@types[@type])
      payload += hex_to_raw_bytes(@rf_addr)
      payload += to_raw_bytes(@room_number)
      payload
    end

    def finalize_payload(data)
      's:' + Base64.encode64(data) + "\r\n"
    end
  end

  class SetTemperature < BaseMessage
    def initialize(rf_addr, room_number, comfort, eco, min, max, offset, window_open, window_open_duration)
      super(rf_addr, room_number, 'Temperatures')
      @comfort_temperature = comfort
      @eco_temperature = eco
      @min_temperature = min
      @max_temperature = max
      @temperature_offset = offset
      @window_open_temperature = window_open
      @window_open_duration = window_open_duration
    end

    def prepare_payload
      payload = prepare_base_payload
      payload += to_raw_bytes((@comfort_temperature * 2).to_s)
      payload += to_raw_bytes((@eco_temperature * 2).to_s)
      payload += to_raw_bytes((@max_temperature * 2).to_s)
      payload += to_raw_bytes((@min_temperature * 2).to_s)
      payload += to_raw_bytes(((@temperature_offset + 3.5) * 2).to_s)
      payload += to_raw_bytes((@window_open_temperature * 2).to_s)
      payload += to_raw_bytes((@window_open_duration / 5).to_s)
      finalize_payload(payload)
    end
  end

  class SetModeAndTemperature < BaseMessage
    @@modes = { 'ModeAuto' => 0x00,
                'ModeManual' => 0x40,
                'ModeVacation' => 0x80,
                'ModeBoost' => 0xc0
    }
    def initialize(rf_addr, room_number, mode, params)
      super(rf_addr, room_number, 'TemperatureAndMode')
      @mode = mode
      @params = params
    end

    def prepare_payload
      payload = prepare_base_payload
      payload += to_raw_bytes((@params['temperature'] * 2) | @@modes[@mode]).to_s
      if @params['end']
        date = DateTime.parse(@params['end'])
        b = date.year - 2000
        a = date.day
        a |= date.month >> 1 << 5
        b |= 0x40 if date.month & 0x01
        payload += to_raw_bytes(a) + to_raw_bytes(b)
        payload += to_raw_bytes((date.hour * 2) + (date.minute >= 30 ? 1 : 0))
      end
      finalize_payload(payload)
    end
  end
end
