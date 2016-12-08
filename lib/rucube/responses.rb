#!/usr/bin/env ruby
require 'time'
require 'base64'

module RuCube
  class Response
    def get_raw_bytes(data)
      data.bytes.map { |b| b.to_s(16) }.join
    end

    def initialize(data, verbose)
      parse(data)
      to_s if verbose == true  
    end
  end

  class HelloResponse < Response
    attr_reader :sn, :rf_address, :fw_version, :http_connection_id, :duty_cycle, :free_mem_slots, :state_cube_time, :ntp_counter, :date

    def parse(data)
      message = data.split(',')
      @sn = message[0]
      @rf_address = message[1]
      @fw_version = message[2]
      @http_connection_id = message[4]
      @duty_cycle = message[5]
      @free_mem_slots = message[6]
      date = message[7]
      time = message[8]
      @state_cube_time = message[9]
      @ntp_counter = message[10]
      raw_date = date[4, 2].to_i(16).to_s + '. ' + date[2, 2].to_i(16).to_s + '. ' + (date[0, 2].to_i(16) + 2000).to_s + ' ' + time[0, 2].to_i(16).to_s + ':' + time[2, 2].to_i(16).to_s
      @date = Time.parse(raw_date)
    end

    def to_s
      print('M message content: ' + 'S/N: ' + @sn + ', FW version: ' + @fw_version + ', Cube time: ' + @date.to_s + "\n")
    end
  end

  class MultiResponse < Response
    attr_reader :rooms, :devices

    def prepare_data(data)
      raw_data = ''
      data.each do |entry|
        raw_data += entry[6..-1]
      end
      Base64.decode64(raw_data)
    end

    def parse(data)
      decoded = prepare_data(data)
      rooms_nr = get_raw_bytes(decoded[2]).to_i(16)
      @rooms = []
      position = 3
      for _i in 0..(rooms_nr - 1)
        room_id = get_raw_bytes(decoded[position]).to_i(16)
        name_length = get_raw_bytes(decoded[position + 1]).to_i(16)
        room_name = decoded[position + 2, name_length]
        room_rf_addr = get_raw_bytes(decoded[position + name_length + 2, 3])
        @rooms.push([room_id, room_name, room_rf_addr])
        position += name_length + 5
      end

      @devices = []
      devices_nr = get_raw_bytes(decoded[position]).to_i(16)
      position += 1
      for _i in 0..(devices_nr - 1)
        device_type = get_raw_bytes(decoded[position]).to_i(16)
        device_rf_address = get_raw_bytes(decoded[position + 1, 3])
        device_sn = decoded[position + 4, 10]
        device_name_length = decoded[position + 13].to_i(16)
        device_name = decoded[position + 15, device_name_length]
        device_room_id = get_raw_bytes(decoded[position + 15 + device_name_length]).to_i(16)
        @devices.push([device_type, device_rf_address, device_sn, device_name, device_room_id])
      end
    end

    def to_s
      print('Cube has ' + @devices.length.to_s + ' device(s) registered and ' + @rooms.length.to_s + " room(s) registered\n")
      print('Rooms: ')
      @rooms.each { |room| print(room[1] + ' (rf addr: ' + room[2] + '), ') }
      print("\nDevices: ")
      @devices.each { |device| print(device[3].to_s + ' (rf addr: ' + device[1].to_s + '), ') }
      print("\n")
    end
  end

  class ConfigResponse < Response
    attr_reader :device, :device_addr, :device_type, :room_id, :firmware_version, :test_result, :serial_number, :portal_enabled, :portal_url, :comfort_temp, :eco_temp, :max_temp, :min_temp, :temp_offset, :window_open_temp, :boost_duration, :decalcification_day, :decalcification_hour, :max_valve, :week_program

    def parse(data)
      @device = data[0, 6]
      decoded = Base64.decode64(data[7..-1])
      _data_length = get_raw_bytes(decoded[0]).to_i(16)
      @device_addr = get_raw_bytes(decoded[1, 3])
      @device_type = get_raw_bytes(decoded[4]).to_i(16)
      @room_id = get_raw_bytes(decoded[5]).to_i(16)
      @firmware_version = get_raw_bytes(decoded[6])
      @test_result = get_raw_bytes(decoded[7]).to_i(16)
      @serial_number = decoded[8, 10]
      parse_cube(decoded[18..-1]) if @device_type == 0
      parse_thermostat(decoded[18..-1]) if @device_type == 1 || @device_type == 2
    end

    def parse_cube(data)
      @portal_enabled = get_raw_bytes(data[11]) == 1
      end_of_url = data.index("\0", 67)
      @portal_url = data[67, end_of_url - 67]
    end

    def parse_thermostat(data)
      @comfort_temp = get_raw_bytes(data[0]).to_i(16) / 2.0
      @eco_temp = get_raw_bytes(data[1]).to_i(16) / 2.0
      @max_temp = get_raw_bytes(data[2]).to_i(16) / 2.0
      @min_temp = get_raw_bytes(data[3]).to_i(16) / 2.0
      @temp_offset = get_raw_bytes(data[4]).to_i(16) / 2.0 - 3.5
      @window_open_temp = get_raw_bytes(data[5]).to_i(16) / 2.0
      @window_open_duration = get_raw_bytes(data[6]).to_i(16) / 2.0
      @boost_duration = get_raw_bytes(data[7]).to_i(16) >> 5 < 7 ? (get_raw_bytes(data[7]).to_i(16) >> 5) * 5 : 60
      @boost_valve = (get_raw_bytes(data[7]).to_i(16) - (get_raw_bytes(data[7]).to_i(16) >> 5 << 5)) * 5
      @decalcification_day = get_raw_bytes(data[8]).to_i(16) >> 5
      @decalcification_hour = get_raw_bytes(data[8]).to_i(16) - (get_raw_bytes(data[8]).to_i(16) >> 5 << 5)
      @max_valve = get_raw_bytes(data[9]).to_i(16) * 100 / 255
      @week_program = parse_week_program(data[11..-1])
    end

    def parse_week_program(data)
      program = []
      for i in 0..6
        day_schedules = []
        position = i * 26
        day_config = data[position, 26]
        start = 0
        (0..25).step(2).each do |index|
          schedule_raw = day_config[index, 2]
          temperature = (get_raw_bytes(schedule_raw[0]).to_i(16) >> 1) / 2.0
          minutes = (get_raw_bytes(schedule_raw[1]).to_i(16) + ((get_raw_bytes(schedule_raw[0]).to_i(16) & 0x01) * 256)) * 5
          day_schedules.push([temperature, start, minutes])
          start = minutes
          break if minutes >= 1440
        end
        program.push(day_schedules)
      end
      program
    end

    def to_s
      if @device_type == 0
        print("Cube config:\n")
        print('  Portal enabled: ' + @portal_enabled.to_s + "\n  Portal URL: " + @portal_url.to_s + "\n")
      else
        print("Device Config:\n" + '  Comfort temp: ' + @comfort_temp.to_s + "\n  Eco temp: " + @eco_temp.to_s + "\n  Max temp: " + @max_temp.to_s + "\n  Min temp: " + @min_temp.to_s + "\n  Temp offset: " + @temp_offset.to_s + "\n  Window open temp: " + @window_open_temp.to_s + "\n  Window open duration: " + @window_open_duration.to_s + "\n  Boost duration: " + @boost_duration.to_s + "\n  Boost valve: " + @boost_valve.to_s + "\n  Max valve: " + @max_valve.to_s + "\n")
      end
    end
  end

  class LResponse < Response
    attr_reader :flag_auto_program, :flag_manual_program, :flag_vacation_program, :flag_boost_program, :flag_dst_active, :flag_gateway_known, :flag_panel_locked, :flag_link_ok, :flag_battery_low, :flag_status_initialized, :flag_is_answer, :flag_is_error, :flag_is_valid, :temperature, :valve_position
    def parse(data)
      decoded = Base64.decode64(data)

      message_length = get_raw_bytes(decoded[0]).to_i(16)
      @rf_addr = get_raw_bytes(decoded[1, 3])
      flags1 = get_raw_bytes(decoded[5]).to_i(16)
      flags2 = get_raw_bytes(decoded[6]).to_i(16)
      @temperature = 0
      @valve_position = 0

      @flag_auto_program = (flags2 & 0x01 || flags2 & 0x02) == 0
      @flag_manual_program = (flags2 & 0x01) == 1 && (flags2 & 0x02) == 0
      @flag_vacation_program = (flags2 & 0x02) == 1 && (flags2 & 0x01) == 0
      @flag_boost_program = (flags2 & 0x01 && flags2 & 0x02) == 1
      @flag_dst_active = flags2 & 0x08 == 1
      @flag_gateway_known = (flags2 & 0x05) == 1
      @flag_panel_locked = (flags2 & 0x06) == 1
      @flag_link_ok = (flags2 & 0x07) == 1
      @flag_battery_low = (flags2 & 0x08) == 1
      @flag_status_initialized = (flags1 & 0x02) == 1
      @flag_is_answer = (flags1 & 0x03) == 0
      @flag_is_error = (flags1 & 0x04) == 1
      @flag_is_valid = (flags1 & 0x05) == 1

      parse_extra_fields(decoded) if message_length > 6
    end

    def parse_extra_fields(data)
      @valve_position = get_raw_bytes(data[7]).to_i(16)
      @temperature = get_raw_bytes(data[8]).to_i(16) / 2.0
    end

    def to_s
      print("Current state: \n")
      print('  Temperature: ' + @temperature.to_s + "\n  Valve position: " + @valve_position.to_s + "\n  Mode: ")
      print("Manual\n") if @flag_manual_program == true
      print("Automatic\n") if @flag_auto_program == true
      print("Boost\n") if @flag_boost_program == true
      print("Vacation\n") if @flag_vacation_program == true
    end
  end

  class SResponse < Response
    attr_reader :duty_cycle, :duty_cycle, :free_mem_slots
    def parse(data)
      message = data.split(',')
      @duty_cycle = message[0].to_i
      @command_success = message[1].to_i == 0
      @free_mem_slots = message[2].to_i
    end

    def to_s
      print("Set Response received, with following: \n")
      print('  Duty cycle: ' + @duty_cycle.to_s + "\n")
      print('  Free memory slots: ' + @free_mem_slots.to_s + "\n")
      print('  Success: ' + @command_success.to_s + "\n")
    end
  end
end
