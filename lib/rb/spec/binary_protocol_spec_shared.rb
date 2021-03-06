# encoding: ascii-8bit
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

require 'spec_helper'

shared_examples_for 'a binary protocol' do
  before(:each) do
    @trans = Thrift::MemoryBufferTransport.new
    @prot = protocol_class.new(@trans)
  end

  it "should define the proper VERSION_1, VERSION_MASK AND TYPE_MASK" do
    expect(protocol_class.const_get(:VERSION_MASK)).to eq(0xffff0000)
    expect(protocol_class.const_get(:VERSION_1)).to eq(0x80010000)
    expect(protocol_class.const_get(:TYPE_MASK)).to eq(0x000000ff)
  end

  it "should make strict_read readable" do
    expect(@prot.strict_read).to eql(true)
  end

  it "should make strict_write readable" do
    expect(@prot.strict_write).to eql(true)
  end    

  it "should write the message header" do
    @prot.write_message_begin('testMessage', Thrift::MessageTypes::CALL, 17)
    expect(@trans.read(@trans.available)).to eq([protocol_class.const_get(:VERSION_1) | Thrift::MessageTypes::CALL, "testMessage".size, "testMessage", 17].pack("NNa11N"))
  end
  
  it "should write the message header without version when writes are not strict" do
    @prot = protocol_class.new(@trans, true, false) # no strict write
    @prot.write_message_begin('testMessage', Thrift::MessageTypes::CALL, 17)
    expect(@trans.read(@trans.available)).to eq("\000\000\000\vtestMessage\001\000\000\000\021")
  end
  
  it "should write the message header with a version when writes are strict" do
    @prot = protocol_class.new(@trans) # strict write
    @prot.write_message_begin('testMessage', Thrift::MessageTypes::CALL, 17)
    expect(@trans.read(@trans.available)).to eq("\200\001\000\001\000\000\000\vtestMessage\000\000\000\021")
  end
  

  # message footer is a noop

  it "should write the field header" do
    @prot.write_field_begin('foo', Thrift::Types::DOUBLE, 3)
    expect(@trans.read(@trans.available)).to eq([Thrift::Types::DOUBLE, 3].pack("cn"))
  end
  
  # field footer is a noop
  
  it "should write the STOP field" do
    @prot.write_field_stop
    expect(@trans.read(1)).to eq("\000")
  end
  
  it "should write the map header" do
    @prot.write_map_begin(Thrift::Types::STRING, Thrift::Types::LIST, 17)
    expect(@trans.read(@trans.available)).to eq([Thrift::Types::STRING, Thrift::Types::LIST, 17].pack("ccN"));
  end
   
  # map footer is a noop
  
  it "should write the list header" do
    @prot.write_list_begin(Thrift::Types::I16, 42)
    expect(@trans.read(@trans.available)).to eq([Thrift::Types::I16, 42].pack("cN"))
  end
  
  # list footer is a noop
  
  it "should write the set header" do
    @prot.write_set_begin(Thrift::Types::I16, 42)
    expect(@trans.read(@trans.available)).to eq([Thrift::Types::I16, 42].pack("cN"))
  end
  
  it "should write a bool" do
    @prot.write_bool(true)
    @prot.write_bool(false)
    expect(@trans.read(@trans.available)).to eq("\001\000")
  end
  
  it "should treat a nil bool as false" do
    @prot.write_bool(nil)
    expect(@trans.read(1)).to eq("\000")
  end
  
  it "should write a byte" do
    # byte is small enough, let's check -128..127
    (-128..127).each do |i|
      @prot.write_byte(i)
      expect(@trans.read(1)).to eq([i].pack('c'))
    end
  end

  it "should clip numbers out of signed range" do
    (128..255).each do |i|
      @prot.write_byte(i)
      expect(@trans.read(1)).to eq([i].pack('c'))
    end
  end

  it "errors out with a Bignum" do
    expect { @prot.write_byte(2**65) }.to raise_error(RangeError)
  end
  
  it "should error gracefully when trying to write a nil byte" do
    expect { @prot.write_byte(nil) }.to raise_error
  end
  
  it "should write an i16" do
    # try a random scattering of values
    # include the signed i16 minimum/maximum
    [-2**15, -1024, 17, 0, -10000, 1723, 2**15-1].each do |i|
      @prot.write_i16(i)
    end
    # and try something out of signed range, it should clip
    @prot.write_i16(2**15 + 5)
    
    expect(@trans.read(@trans.available)).to eq("\200\000\374\000\000\021\000\000\330\360\006\273\177\377\200\005")
    
    # a Bignum should error
    # lambda { @prot.write_i16(2**65) }.should raise_error(RangeError)
  end
  
  it "should error gracefully when trying to write a nil i16" do
    expect { @prot.write_i16(nil) }.to raise_error
  end
  
  it "should write an i32" do
    # try a random scattering of values
    # include the signed i32 minimum/maximum
    [-2**31, -123123, -2532, -3, 0, 2351235, 12331, 2**31-1].each do |i|
      @prot.write_i32(i)
    end
    # try something out of signed range, it should clip
    expect(@trans.read(@trans.available)).to eq("\200\000\000\000" + "\377\376\037\r" + "\377\377\366\034" + "\377\377\377\375" + "\000\000\000\000" + "\000#\340\203" + "\000\0000+" + "\177\377\377\377")
    [2 ** 31 + 5, 2 ** 65 + 5].each do |i|
      expect { @prot.write_i32(i) }.to raise_error(RangeError)  
    end
  end
  
  it "should error gracefully when trying to write a nil i32" do
    expect { @prot.write_i32(nil) }.to raise_error
  end
  
  it "should write an i64" do
    # try a random scattering of values
    # try the signed i64 minimum/maximum
    [-2**63, -12356123612323, -23512351, -234, 0, 1231, 2351236, 12361236213, 2**63-1].each do |i|
      @prot.write_i64(i)
    end
    # try something out of signed range, it should clip
    expect(@trans.read(@trans.available)).to eq(["\200\000\000\000\000\000\000\000",
      "\377\377\364\303\035\244+]",
      "\377\377\377\377\376\231:\341",
      "\377\377\377\377\377\377\377\026",
      "\000\000\000\000\000\000\000\000",
      "\000\000\000\000\000\000\004\317",
      "\000\000\000\000\000#\340\204",
      "\000\000\000\002\340\311~\365",
      "\177\377\377\377\377\377\377\377"].join(""))
    expect { @prot.write_i64(2 ** 65 + 5) }.to raise_error(RangeError)
  end
  
  it "should error gracefully when trying to write a nil i64" do
    expect { @prot.write_i64(nil) }.to raise_error
  end
  
  it "should write a double" do
    # try a random scattering of values, including min/max
    values = [Float::MIN,-1231.15325, -123123.23, -23.23515123, 0, 12351.1325, 523.23, Float::MAX]
    values.each do |f|
      @prot.write_double(f)
      expect(@trans.read(@trans.available)).to eq([f].pack("G"))
    end
  end
  
  it "should error gracefully when trying to write a nil double" do
    expect { @prot.write_double(nil) }.to raise_error
  end

  if RUBY_VERSION >= '1.9'
    it 'should write a string' do
      str = 'abc'
      @prot.write_string(str)
      a = @trans.read(@trans.available)
      expect(a.encoding).to eq(Encoding::BINARY)
      expect(a.unpack('C*')).to eq([0x00, 0x00, 0x00, 0x03, 0x61, 0x62, 0x63])
    end

    it 'should write a string with unicode characters' do
      str = "abc \u20AC \u20AD".encode('UTF-8')
      @prot.write_string(str)
      a = @trans.read(@trans.available)
      expect(a.encoding).to eq(Encoding::BINARY)
      expect(a.unpack('C*')).to eq([0x00, 0x00, 0x00, 0x0B, 0x61, 0x62, 0x63, 0x20,
                                0xE2, 0x82, 0xAC, 0x20, 0xE2, 0x82, 0xAD])
    end

    it 'should write should write a string with unicode characters and transcoding' do
      str = "abc \u20AC".encode('ISO-8859-15')
      @prot.write_string(str)
      a = @trans.read(@trans.available)
      expect(a.encoding).to eq(Encoding::BINARY)
      expect(a.unpack('C*')).to eq([0x00, 0x00, 0x00, 0x07, 0x61, 0x62, 0x63, 0x20, 0xE2, 0x82, 0xAC])
    end

    it 'should write a binary string' do
      buffer = [0, 1, 2, 3].pack('C*')
      @prot.write_binary(buffer)
      a = @trans.read(@trans.available)
      expect(a.encoding).to eq(Encoding::BINARY)
      expect(a.unpack('C*')).to eq([0x00, 0x00, 0x00, 0x04, 0x00, 0x01, 0x02, 0x03])
    end
  else
    it 'should write a string' do
      str = 'abc'
      @prot.write_string(str)
      a = @trans.read(@trans.available)
      expect(a.unpack('C*')).to eq([0x00, 0x00, 0x00, 0x03, 0x61, 0x62, 0x63])
    end

    it 'should write a binary string' do
      buffer = [0, 1, 2, 3].pack('C*')
      @prot.write_binary(buffer)
      a = @trans.read(@trans.available)
      expect(a.unpack('C*')).to eq([0x00, 0x00, 0x00, 0x04, 0x00, 0x01, 0x02, 0x03])
    end
  end

  it "should error gracefully when trying to write a nil string" do
    expect { @prot.write_string(nil) }.to raise_error
  end
  
  it "should write the message header without version when writes are not strict" do
    @prot = protocol_class.new(@trans, true, false) # no strict write
    @prot.write_message_begin('testMessage', Thrift::MessageTypes::CALL, 17)
    expect(@trans.read(@trans.available)).to eq("\000\000\000\vtestMessage\001\000\000\000\021")
  end
    
  it "should write the message header with a version when writes are strict" do
    @prot = protocol_class.new(@trans) # strict write
    @prot.write_message_begin('testMessage', Thrift::MessageTypes::CALL, 17)
    expect(@trans.read(@trans.available)).to eq("\200\001\000\001\000\000\000\vtestMessage\000\000\000\021")
  end
  
  # message footer is a noop
  
  it "should read a field header" do
    @trans.write([Thrift::Types::STRING, 3].pack("cn"))
    expect(@prot.read_field_begin).to eq([nil, Thrift::Types::STRING, 3])
  end
  
  # field footer is a noop
  
  it "should read a stop field" do
    @trans.write([Thrift::Types::STOP].pack("c"));
    expect(@prot.read_field_begin).to eq([nil, Thrift::Types::STOP, 0])
  end

  it "should read a map header" do
    @trans.write([Thrift::Types::DOUBLE, Thrift::Types::I64, 42].pack("ccN"))
    expect(@prot.read_map_begin).to eq([Thrift::Types::DOUBLE, Thrift::Types::I64, 42])
  end
  
  # map footer is a noop
  
  it "should read a list header" do
    @trans.write([Thrift::Types::STRING, 17].pack("cN"))
    expect(@prot.read_list_begin).to eq([Thrift::Types::STRING, 17])
  end
  
  # list footer is a noop
  
  it "should read a set header" do
    @trans.write([Thrift::Types::STRING, 17].pack("cN"))
    expect(@prot.read_set_begin).to eq([Thrift::Types::STRING, 17])
  end
  
  # set footer is a noop
  
  it "should read a bool" do
    @trans.write("\001\000");
    expect(@prot.read_bool).to eq(true)
    expect(@prot.read_bool).to eq(false)
  end
  
  it "should read a byte" do
    [-128, -57, -3, 0, 17, 24, 127].each do |i|
      @trans.write([i].pack("c"))
      expect(@prot.read_byte).to eq(i)
    end
  end
  
  it "should read an i16" do
    # try a scattering of values, including min/max
    [-2**15, -5237, -353, 0, 1527, 2234, 2**15-1].each do |i|
      @trans.write([i].pack("n"));
      expect(@prot.read_i16).to eq(i)
    end
  end
  
  it "should read an i32" do
    # try a scattering of values, including min/max
    [-2**31, -235125, -6236, 0, 2351, 123123, 2**31-1].each do |i|
      @trans.write([i].pack("N"))
      expect(@prot.read_i32).to eq(i)
    end
  end
  
  it "should read an i64" do
    # try a scattering of values, including min/max
    [-2**63, -123512312, -6346, 0, 32, 2346322323, 2**63-1].each do |i|
      @trans.write([i >> 32, i & 0xFFFFFFFF].pack("NN"))
      expect(@prot.read_i64).to eq(i)
    end
  end
  
  it "should read a double" do
    # try a random scattering of values, including min/max
    [Float::MIN, -231231.12351, -323.233513, 0, 123.2351235, 2351235.12351235, Float::MAX].each do |f|
      @trans.write([f].pack("G"));
      expect(@prot.read_double).to eq(f)
    end
  end

  if RUBY_VERSION >= '1.9'
    it 'should read a string' do
      # i32 of value 3, followed by three characters/UTF-8 bytes 'a', 'b', 'c'
      buffer = [0x00, 0x00, 0x00, 0x03, 0x61, 0x62, 0x63].pack('C*')
      @trans.write(buffer)
      a = @prot.read_string
      expect(a).to eq('abc'.encode('UTF-8'))
      expect(a.encoding).to eq(Encoding::UTF_8)
    end

    it 'should read a string containing unicode characters from UTF-8 encoded buffer' do
      # i32 of value 3, followed by one character U+20AC made up of three bytes
      buffer = [0x00, 0x00, 0x00, 0x03, 0xE2, 0x82, 0xAC].pack('C*')
      @trans.write(buffer)
      a = @prot.read_string
      expect(a).to eq("\u20AC".encode('UTF-8'))
      expect(a.encoding).to eq(Encoding::UTF_8)
    end

    it 'should read a binary string' do
      buffer = [0x00, 0x00, 0x00, 0x04, 0x00, 0x01, 0x02, 0x03].pack('C*')
      @trans.write(buffer)
      a = @prot.read_binary
      expect(a).to eq([0x00, 0x01, 0x02, 0x03].pack('C*'))
      expect(a.encoding).to eq(Encoding::BINARY)
    end
  else
    it 'should read a string' do
      # i32 of value 3, followed by three characters/UTF-8 bytes 'a', 'b', 'c'
      buffer = [0x00, 0x00, 0x00, 0x03, 0x61, 0x62, 0x63].pack('C*')
      @trans.write(buffer)
      expect(@prot.read_string).to eq('abc')
    end

    it 'should read a binary string' do
      buffer = [0x00, 0x00, 0x00, 0x04, 0x00, 0x01, 0x02, 0x03].pack('C*')
      @trans.write(buffer)
      a = @prot.read_binary
      expect(a).to eq([0x00, 0x01, 0x02, 0x03].pack('C*'))
    end
  end

  it "should perform a complete rpc with no args or return" do
    srv_test(
      proc {|client| client.send_voidMethod()},
      proc {|client| expect(client.recv_voidMethod).to eq(nil)}
    )
  end

  it "should perform a complete rpc with a primitive return type" do
    srv_test(
      proc {|client| client.send_primitiveMethod()},
      proc {|client| expect(client.recv_primitiveMethod).to eq(1)}
    )
  end

  it "should perform a complete rpc with a struct return type" do
    srv_test(
      proc {|client| client.send_structMethod()},
      proc {|client|
        result = client.recv_structMethod
        result.set_byte_map = nil
        result.map_byte_map = nil
        expect(result).to eq(Fixtures::COMPACT_PROTOCOL_TEST_STRUCT)
      }
    )
  end

  def get_socket_connection
    server = Thrift::ServerSocket.new("localhost", 9090)
    server.listen
    
    clientside = Thrift::Socket.new("localhost", 9090)
    clientside.open
    serverside = server.accept
    [clientside, serverside, server]
  end

  def srv_test(firstblock, secondblock)
    clientside, serverside, server = get_socket_connection

    clientproto = protocol_class.new(clientside)
    serverproto = protocol_class.new(serverside)

    processor = Thrift::Test::Srv::Processor.new(SrvHandler.new)

    client = Thrift::Test::Srv::Client.new(clientproto, clientproto)

    # first block
    firstblock.call(client)

    processor.process(serverproto, serverproto)

    # second block
    secondblock.call(client)
  ensure
    clientside.close
    serverside.close
    server.close
  end

  class SrvHandler 
    def voidMethod()
    end
    
    def primitiveMethod
      1
    end
    
    def structMethod
      Fixtures::COMPACT_PROTOCOL_TEST_STRUCT
    end
  end
end
