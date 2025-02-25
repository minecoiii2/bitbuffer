local bitbuffer = require('./bitbuffer')

local text = 'Hello, World!'
local buf = bitbuffer.new(#text * 2 + 3)

-- write Hello, World!
buf:writeString(text, true)

-- write a space
buf:writeBits(string.byte(' '), 8)

-- write Hello, World! using uint8
for i = 1, #text, 1 do
    local l = string.sub(text, i, i)
    buf:writeBits(string.byte(l), 8)
end

-- render the final buffer
print(buf:toString()) -- Output: Hello, World! Hello, World!