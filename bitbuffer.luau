-- made by minecoiii

export type format = 'f32'|'f64'|'u8'|'i8'|'u16'|'i16'|'u32'|'i32'

export type bitbuffer = {
	pointer: number, -- in bits
	len: number, -- in bits
	buffer: buffer,
	
	-- throw error if pointer + offsetBits is out of bounds
	outOfBoundsCheck: (bitbuffer, offsetBits: number) -> nil,
	
	-- read/writes bits to buffer	
	writeBits: (bitbuffer, value: number, sizeBits: number) -> nil,
	readBits: (bitbuffer, sizeBits: number) -> number,
	
	-- read/writes formats to buffer
	writeFormat: (bitbuffer, format: format, value: number) -> nil,
	readFormat: (bitbuffer, format: format) -> number,	
	
	-- read/write strings to buffer
	writeString: (bitbuffer, str: string, excludeLength: boolean?, lengthFormat: format?) -> nil,
	readString: (bitbuffer, length: number?, lengthFormat: format?) -> string,
	
	-- finalize
	toString: (bitbuffer) -> string,

	-- pointers
	
	-- floor pointer to nearest byte
	floorPointer: (bitbuffer) -> nil,
	-- offset pointer by bits
	offsetPointer: (bitbuffer, offsetBits: number) -> nil,
	-- set pointer to specified amount of bits
	setPointer: (bitbuffer, bits: number) -> nil,
}

-- prints num as binary value, bits for precision, ... for any appended strings
function printBinary(num: number, bits: number?, ...: string)
	local bits = bits or 8

	local binaryStr = ''
	for i = bits - 1, 0, -1 do
		binaryStr ..= bit32.band(bit32.rshift(num, i), 1)
		if i % 4 == 0 and i ~= 0 then
			binaryStr ..= ' '
		end
	end

	print(binaryStr, ...)
end

local bitbuffer = {
	printBinary = printBinary,
}
bitbuffer.__index = bitbuffer

-- constructors

function bitbuffer.fromBuffer(buf: buffer)
	return setmetatable({
		pointer = 0, -- 0-indexed
		len = buffer.len(buf) * 8,
		buffer = buf
	}, bitbuffer)
end

function bitbuffer.new(sizeBytes: number)
	return bitbuffer.fromBuffer(buffer.create(sizeBytes))
end

function bitbuffer.fromString(str: string)
	return bitbuffer.fromBuffer(buffer.fromstring(str))
end

-- error handling

function bitbuffer.outOfBoundsCheck(self, offsetBits: number)
	assert(self.pointer // 8 + offsetBits < self.len, 'Attempt to access bytes out of buffer bounds')
end

-- base write/read bits

function bitbuffer.writeBits(self, n: number, sizeBits: number)
	local pointer = self.pointer
	self:outOfBoundsCheck(sizeBits)
	
	local minByte = (pointer) // 8
	local maxByte = (pointer + sizeBits - 1) // 8
	
	local pointerBig = 8 - pointer % 8
	
	local remainingBits = sizeBits

	for byte = minByte, maxByte, 1 do
		local v = buffer.readu8(self.buffer, byte)
		
		if byte == minByte then
			-- write first bits, can be last byte
			local cappedSize = math.min(pointerBig, sizeBits)
			remainingBits -= cappedSize
			local shifted = bit32.rshift(n, remainingBits)
			buffer.writeu8(self.buffer, byte, 
				if cappedSize == 8 then 
					shifted 
				else 
					bit32.replace(v, shifted, pointerBig - cappedSize
			, cappedSize))
		elseif byte == maxByte then
			-- write the last byte, if minByte == maxByte: handle minByte instead of maxByte
			-- no need to abt remainingBits
			buffer.writeu8(self.buffer, byte, bit32.replace(v, n, 8 - remainingBits, remainingBits))
		else--if byte > minByte and byte < maxByte then
			-- write the middle bytes 
			remainingBits -= 8
			local shifted = bit32.rshift(n, remainingBits)
			buffer.writeu8(self.buffer, byte, shifted)
		end
	end
	
	self:offsetPointer(sizeBits)
end

function bitbuffer.readBits(self, sizeBits: number)
	local pointer = self.pointer
	self:outOfBoundsCheck(sizeBits)

	local minByte = (pointer) // 8
	local maxByte = (pointer + sizeBits - 1) // 8

	local pointerBig = 8 - pointer % 8

	local remainingBits = sizeBits
	local v = 0

	for byte = minByte, maxByte, 1 do
		local n = buffer.readu8(self.buffer, byte)

		if byte == minByte then
			-- read first bits
			local cappedSize = math.min(pointerBig, sizeBits)
			remainingBits -= cappedSize
			v = bit32.lshift(
				if cappedSize == 8 then 
					n 
				else 
					bit32.extract(n, pointerBig - cappedSize, cappedSize)
			, remainingBits)
		elseif byte == maxByte then
			-- extract last bits
			v += bit32.extract(n, 8 - remainingBits, remainingBits)
		else--if byte > minByte and byte < maxByte then
			-- middle bits boring
			remainingBits -= 8
			v += bit32.lshift(n, remainingBits)
		end
	end

	self:offsetPointer(sizeBits)
	
	return v
end

-- base format functions
local formatsToBytes = {
	['f32'] = 4,
	['f64'] = 8,
	
	['u8'] = 1,
	['i8'] = 1,
	['u16'] = 2,
	['i16'] = 2,
	['u32'] = 4,
	['i32'] = 4,
}

function bitbuffer.writeFormat(self, format: format, value: number)
	local bytes = formatsToBytes[format]
	local f = buffer['write' .. format]
	
	 -- believe it or not this is faster than string.unpack/pack
	local transfer = buffer.create(bytes)
	f(transfer, 0, value)
	
	for i = 0, bytes - 1, 1 do
		self:writeBits(buffer.readu8(transfer, i), 8)
	end
end

function bitbuffer.readFormat(self, format: format)
	local bytes = formatsToBytes[format]
	local transfer = buffer.create(bytes)

	for i = 0, bytes - 1, 1 do
		buffer.writeu8(transfer, i, self:readBits(8))
	end
	
	return buffer['read' .. format](transfer, 0)
end

-- string

function bitbuffer.writeString(self, str: string, excludeLength: boolean?, lengthFormat: format?)
	local len = #str
	
	if excludeLength ~= true then
		self:writeFormat(lengthFormat or 'i16', len)
	end
	
	for i = 1, len, 1 do
		self:writeBits(string.byte(str, i), 8)
	end
end

function bitbuffer.readString(self, length: number?, lengthFormat: format?)
	local length = length or self:readFormat(lengthFormat or 'i16')
	
	local str = ''
	for i = 1, length, 1 do
		str ..= string.char(self:readBits(8))
	end
	return str
end

-- finalizing

function bitbuffer.toString(self)
	return buffer.tostring(self.buffer)
end

-- pointer manipulation

function bitbuffer.floorPointer(self)
	self.pointer //= 8
end

function bitbuffer.offsetPointer(self, bits: number)
	self:outOfBoundsCheck(bits)
	self.pointer += bits
end

function bitbuffer.setPointer(self, bits: number)
	self:outOfBoundsCheck(bits - self.pointer)
	self.pointer = bits
end

return bitbuffer