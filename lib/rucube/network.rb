#!/usr/bin/env ruby
require 'socket'
require 'timeout'
require 'rucube/responses'

module RuCube
  class Network

    def initialize(verbose = false)
        @verbose = verbose
    end
  
    def create_socket(ip, port)
      TCPSocket.open(ip, port)
    end

    def receive(socket)
      read = true
      data_raw = ''
      while read == true
        response = ''
        begin timeout(1) do
          response = socket.recv(4096)
        end
      rescue Timeout::Error
      end
        read = response.length > 0 ? true : false
        data_raw += response
      end
      data = []
      data_raw.lines.map { |raw_line| data.push(raw_line.chop) }
      while data.length > 0
        message = data[0]
        message_type = message[0]
        if message_type == 'M'
          multi_response = [message[2..-1]]
          while data.length > 1 && data[1][0] == message_type
            multi_response.push(data[1][2..-1])
            data.delete_at(1)
          end
          response = parse_message(message_type, multi_response)
        else
          response = parse_message(message_type, message[2..-1])
        end
        data.shift
      end
    end

    def send_message(socket, data)
      socket.write(data)
      receive(socket)
    end

    def parse_message(message_type, data)
      classes = {
        'H' => HelloResponse,
        'M' => MultiResponse,
        'C' => ConfigResponse,
        'L' => LResponse,
        'S' => SResponse
      }
      handler = classes.fetch(message_type)
      handler.new(data, @verbose)
    end

    def get_raw_bytes(data)
      data.bytes.map { |b| b.to_s(16) }.join
    end

    def discover
      sender = UDPSocket.new
      receiver = UDPSocket.new
      sender.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      sender.send('eQ3Max*.**********I', 0, '255.255.255.255', 23_272)
      receiver.bind('0.0.0.0', 23_272)
      response = nil
      address = nil
      begin timeout(5) do
        response, address = receiver.recvfrom(50)
      end
      rescue Timeout::Error
        print('No Cube has been found!')
        return
      end
      cube_sn = response[8, 10]
      rf_addr = get_raw_bytes(response[21, 3])
      fw_version = get_raw_bytes(response[24, 2])
      print("Cube Found!\nS/N: " + cube_sn + ', RF addr: ' + rf_addr + ', FW version: ' + fw_version + ', IP: ' + address[3])
      sender.close
      receiver.close
      address[2]
    end
  end
end
