# BitBuffer.luau

BitBuffer - a module that extends the the built-in buffer library
by facilitating bit-level writing/reading.

## Usage

BitBuffer comes with three constructors, use either of these to create a bitbuffer object

```
bitbuffer.new(bytes: number)
bitbuffer.fromBuffer(buffer: buffer)
bitbuffer.fromString(str: string)
```

**Pointer/Cursor**

Unlike the buffer library Bitbuffer keeps track of an internal pointer/cursor 
that moves with your reading/writing

Pointer is in bits; not bytes and is also 0-indexed unlike most of lua, this is because the buffer lib 
also is 0-indexed and it makes my life easier

The pointer automatically moves as you read/write bits but you can manually move it

```lua
-- floor the pointer to the nearest byte
buffer:floorPointer()
-- offset the pointer 
buffer:offsetPointer(bits: number)
-- set the pointer to a specific bit amount
buffer:setPointer(bits: number)
```

**Base Read/Writing**

`:writeBits()` and `:readBits()` are the base functions that power this library.
If you need precise bit-level control over the buffer these functions are your best bet

⚠️ **Notice:** Currently both functions use a custom bit-manipulation implementation 
however that might change with the full-release of `:writebits()` to the base buffer lib

Note that by default `:writeBits()` writes in big-endian instead of little-endian, that does not apply to `:writeFormat()`

You can provide specific binary sequences and their relative bit-size to write to the array

```lua
-- write the number 3 as a uint8
buffer:writeBits(0b011, 8)

buffer:floorPointer() -- floor the pointer to read the written bits
-- printBinary is a debug function included in the library
printBinary(buffer:readBits(8), 4) -- Output: 0011
```

**Reading/Writing Formats**

BitBuffer only uses the default buffer lib formats:
`u8, i8, u16, i16, u32, i32, f32, f64`

Note that `:writeFormat()` writes in little-endian unlike its base function

```lua
-- write -522 as a signed 16-bit integer
buffer:writeFormat('i16', -522)

buffer:floorPointer() -- for reading
print(buffer:readFormat('i16')) -- Output: -522

--------------------------------

-- write 52.692 as a 32-bit float
buffer:writeFormat('f32', 52.692)

buffer:floorPointer() -- for reading
print(buffer:readFormat('f32')) -- Output: ~ 52.692
```

**Reading/Writing Strings**

By default `:writeStrings()` also writes the length of the string up-front
this can be disabled by true-ing the `excludeLength` parameter

The format of the length can also be changed by using `lengthFormat`, defaults to `i16`

`:readString()` has an optional `length` parameter, by default it reads the first `lenghtFormat or i16` value for the length

```lua
local hello = 'Hello, World!'
buffer:writeString(hello, true) -- write the string but exclude the length

-- reset pointer to the start of the buffer
buffer:setPointer(0)
-- manually set the length of the string
print(buffer:readString(#hello)) -- Output: Hello, World!
```

**Finalize**

To finish off, render out the final buffer using `:toString()`

```lua
buffer:toString()
```

**Misc**

Attempting to access/point to out-of-buffer bits/bytes will result in an error

The `printBinary()` function can be accessed directly from the library; `bitbuffer.printBinary()`

This library is inpsired by kalabgs's [BitBuffer](https://devforum.roblox.com/t/bifbuffer-fast-and-compact-bitwise-buffer/3044870/4)

## License

Do anything you want with my code, credits not needed

[UNI](https://choosealicense.com/licenses/unlicense/)