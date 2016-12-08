require 'spec_helper'

describe RuCube do
  it 'has a version number' do
    expect(RuCube::VERSION).not_to be nil
  end

  describe '#score'
  
	context 'hex text to byte' do
		it 'compare types and values' do
			test = RuCube::BaseMessage.new(1, 1, 1)
	  		expect(test.hex_to_raw_bytes("0a")).to eq "\n"
	  	end

	  	it 'number to bytes' do
			test = RuCube::BaseMessage.new(1, 1, 1)
	  		expect(test.to_raw_bytes(87)).to eq "W"
	  	end
	end

	context 'data manipulation' do 
		it 'finalizes message' do
			test = RuCube::BaseMessage.new(1, 1, 1)
	  		expect(test.finalize_payload("TEST")).to eq "s:VEVTVA==\n\r\n"
	  	end
	end

	context 'format' do 
		it 'creates correct set message' do
			test = RuCube::SetModeAndTemperature.new("0c322b", 1, 'ModeAuto', {'temperature' => 16})
	  		expect(test.prepare_payload()).to eq "s:AARAAAAADDIrASA=\n\r\n"
	  	end
	end

	context 'discovery' do 
		it 'it doscovers cube' do
			test = RuCube::Network.new()
	  		expect(test.discover()).to eq "192.168.1.147"
	  	end
	end
end
