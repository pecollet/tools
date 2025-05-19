
bolt_protocol = Proto("Bolt",  "Bolt Protocol")


message_tag = ProtoField.string("bolt.message_tag", "messageTag", base.ASCII, "BOLT message tag")
supported_version = ProtoField.string("bolt.supportedVersion", "supportedVersion", base.ASCII, "Version supported by client")
selected_version = ProtoField.string("bolt.version", "selectedVersion", base.ASCII, "Version selected by server")
chunk = ProtoField.string("bolt.chunk", "chunk", base.ASCII, "BOLT chunk")
chunk_size = ProtoField.int32("bolt.chunk_size", "chunkSize", base.DEC)
fields_count = ProtoField.int32("bolt.fields_count", "fieldsCount", base.DEC)
record_count = ProtoField.int32("bolt.record_count", "recordCount", base.DEC)
record = ProtoField.string("bolt.record", "record", base.ASCII, "BOLT result record")

bolt_protocol.fields = {message_tag, supported_version, selected_version, chunk_size, fields_count, record_count, record}

function dedupeList(list)
  local hash = {}
  local tmp = {}
  local res = {}

  for _,v in ipairs(list) do
     if (not hash[v]) then
         tmp[#tmp+1] = v 
         hash[v] = 1
     else
         hash[v] = hash[v] + 1
     end
  end
  for _,v in ipairs(tmp) do
    if (hash[v] == 1) then
      res[#res+1] = v
    else
      res[#res+1] = v .. " (x" .. hash[v] ..")"
    end
  end
  return res
end

function get_message_name(tag)
  local message_name = "Unknown"

  if     tag ==   1 then message_name = "HELLO"			--0x01
  elseif tag ==   2 then message_name = "GOODBYE"		--0x02
  elseif tag ==  15 then message_name = "RESET"     --0x0f
  elseif tag ==  16 then message_name = "RUN"       --0x10 
  elseif tag ==  17 then message_name = "BEGIN"			--0x11
  elseif tag ==  18 then message_name = "COMMIT"		--0x12
  elseif tag ==  19 then message_name = "ROLLBACK"	--0x13
  elseif tag ==  47 then message_name = "DISCARD"		--0x2f
  elseif tag ==  63 then message_name = "PULL" 			--0x3f
  elseif tag ==  84 then message_name = "TELEMETRY" --0x54
  elseif tag == 102 then message_name = "ROUTE"     --0x66   4.3 protocol
  elseif tag == 106 then message_name = "LOGON"     --0x6A
  elseif tag == 107 then message_name = "LOGOFF"    --0x6B
  elseif tag == 112 then message_name = "SUCCESS"   --0x70
  elseif tag == 113 then message_name = "RECORD"    --0x71  
  elseif tag == 126 then message_name = "IGNORED"   --0x7e
  elseif tag == 127 then message_name = "FAILURE"   --0x7f
  end

  return message_name
end

function read_next_value(subtree, buffer, offset, treeFieldName)
  --
  local marker=readBuffer(buffer,offset,1):uint()

  if      marker == 0xc1 then -- float 8 bytes                                      X
    subtree:add(treeFieldName or '(float)', readBuffer(buffer,offset+1, 8):float())
    return offset + 1 + 8
  elseif  marker == 0xc2 then -- boolean false                                      X
    subtree:add(treeFieldName or '(boolean)', 'false')
    return offset + 1
  elseif  marker == 0xc3 then -- boolean true                                       X
    subtree:add(treeFieldName or '(boolean)', 'true')     
    return offset + 1
  elseif  marker == 0xc8 then -- INT 8bit                                           X
    subtree:add(treeFieldName or '(INT_8)', readBuffer(buffer,offset+1, 1):int())            
    return offset + 1 + 1
  elseif  marker == 0xc9 then -- INT 16bit                                          X
    subtree:add(treeFieldName or '(INT_16)', readBuffer(buffer,offset+1, 2):int())
    return offset + 1 + 2
  elseif  marker == 0xca then -- INT 32bit                                          X
    subtree:add(treeFieldName or '(INT_32)', readBuffer(buffer,offset+1, 4):int())               
    return offset + 1 + 4    
  elseif  marker == 0xcb then -- INT 64bit                                          X
    subtree:add(treeFieldName or '(INT_64)', readBuffer(buffer,offset+1, 8):int64():tonumber())           
    return offset + 1 + 8
  elseif  marker == 0xcc then -- byte array ; next byte is array size
    local array_size=readBuffer(buffer,offset+1, 1):int()
    subtree:add(treeFieldName or '(bytes)', readBuffer(buffer,offset+2, array_size))
    return offset + 2 + array_size
  elseif  marker == 0xcd then -- bytes (size : 2 bytes)                                             X
    local array_size=readBuffer(buffer,offset+1, 2):int()
    subtree:add(treeFieldName or '(bytes)', readBuffer(buffer,offset+3, array_size))
    return offset + 3 + array_size
  elseif  marker == 0xce then -- bytes (size 4 bytes)
    local array_size=readBuffer(buffer,offset+1, 4):int()
    subtree:add(treeFieldName or '(bytes)', readBuffer(buffer,offset+5, array_size))
    return offset + 5 + array_size
  elseif  (marker >=  0x80 and marker <=   0x8f) then  --STRING (size 0-15 ascii chars)             X
      local str_len=marker - 0x80
      local str = readBuffer(buffer,offset+1, str_len):string()
      temp=str
      subtree:add(treeFieldName or '(string)', str)
      return offset + 1 + str_len
  elseif  marker == 0xd0 then -- STRING 8bit  ; next byte is size in bytes                          X
      local str_len= readBuffer(buffer,offset+1,1):uint()
      local str = readBuffer(buffer,offset+2, str_len):string()
      temp=str
      subtree:add(treeFieldName or '(string)', str)
      return offset + 2 + str_len
  elseif  marker == 0xd1 then -- STRING 16bit ; next 2 bytes is size in bytes                       X
      local str_len= readBuffer(buffer,offset+1,2):uint()
      local str = readBuffer(buffer,offset+3, str_len):string()
      temp=str
      subtree:add(treeFieldName or '(string)', str)
      return offset + 3 + str_len
  elseif  marker == 0xd2 then -- STRING 32bit ; next 4
      local str_len= readBuffer(buffer,offset+1,4):uint()
      local str = readBuffer(buffer,offset+5, str_len):string()
      temp=str
      subtree:add(treeFieldName or '(string)', str)
      return offset + 5 + str_len
  elseif  (marker >=  0xf0 and marker <=   0xff) then  --TINY_INT negative numbers -16 to -1        x
      subtree:add(treeFieldName or '(tiny_int)', marker - 0xf0 - 16  )
      return offset + 1      
  elseif  (marker >=  0x00 and marker <=   0x7f) then  --TINY_INT positive numbers 0 to 127         x
      subtree:add(treeFieldName or '(tiny_int)', marker  )
      return offset + 1
  elseif  (marker >=  0x90 and marker <=   0x9f) then  --LIST 0-15 items                            X
      local list_size=marker - 0x90
      return readList(buffer, subtree, offset, offset+1, list_size, treeFieldName)
  elseif  marker == 0xd4 then -- LIST 8bit  ; next byte is size                                     X
      local list_size=readBuffer(buffer,offset+1, 1):uint()
      return readList(buffer, subtree, offset, offset+2, list_size, treeFieldName)
  elseif  marker == 0xd5 then -- LIST 16bit ; next 2 bytes is size                                  X
      local list_size=readBuffer(buffer,offset+1, 2):uint()
      return readList(buffer, subtree, offset, offset+3, list_size, treeFieldName)
  elseif  marker == 0xd6 then -- LIST 32 bits ; next 4
      local list_size=readBuffer(buffer,offset+1, 4):uint()
      return readList(buffer, subtree, offset, offset+5, list_size, treeFieldName)
  elseif  (marker >=  0xa0 and marker <=   0xaf) then       --map of size 0-15                      X
      local map_size=marker - 0xa0 --extract the last 4 bits by removing 0xA
      return readMap(buffer, subtree, offset, offset+1, map_size, treeFieldName)
  elseif marker ==   0xd8 then       --map 8bit size in next byte                                   X
      local map_size=readBuffer(buffer,offset+1, 1):uint()
      return readMap(buffer, subtree, offset, offset+2, map_size, treeFieldName)
  elseif marker ==   0xd9 then       --map 16bit size in next two bytes
      local map_size=readBuffer(buffer,offset+1, 2):uint()
      return readMap(buffer, subtree, offset, offset+3, map_size, treeFieldName)
  elseif marker ==   0xda then       --map 32bit size in next 4 bytes
      local map_size=readBuffer(buffer,offset+1, 4):uint()
      return readMap(buffer, subtree, offset, offset+5, map_size, treeFieldName)
  elseif (marker >=   0xb0 and marker <=   0xbf) then  --structure of size 0-15 ; next byte is tag
      local struct_size=marker - 0xb0
      local struct_tag=readBuffer(buffer,offset+1, 1):uint()
      if struct_tag == 0x4e then  --Node  
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "Node at offset " .. offset)
          local id_end_offset = read_next_value(structTree, buffer, offset+2, "id: ")
          local labels_end_offset = read_next_value(structTree, buffer, id_end_offset, "labels: ")
          local props_end_offset = read_next_value(structTree, buffer, labels_end_offset, "properties: ")
          return props_end_offset
      elseif struct_tag == 0x52 then  --Relationship
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "Relationship at offset " .. offset)
          local id_end_offset = read_next_value(structTree, buffer, offset+2, "id: ")
          local startnode_end_offset = read_next_value(structTree, buffer, id_end_offset, "startNodeId: ")
          local endnode_end_offset = read_next_value(structTree, buffer, startnode_end_offset, "endNodeId: ")
          local type_end_offset = read_next_value(structTree, buffer, endnode_end_offset, "type: ")
          local props_end_offset = read_next_value(structTree, buffer, type_end_offset, "properties: ")
          return props_end_offset
      elseif struct_tag == 0x72 then  --Unbounded Relationship
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "Relationship at offset " .. offset)
          local id_end_offset = read_next_value(structTree, buffer, offset+2, "id: ")
          local type_end_offset = read_next_value(structTree, buffer, id_end_offset, "type: ")
          local props_end_offset = read_next_value(structTree, buffer, type_end_offset, "properties: ")
          return props_end_offset
      elseif struct_tag == 0x50 then  --Path
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "Path at offset " .. offset)
          local nodes_end_offset = read_next_value(structTree, buffer, offset+2, "nodes: ")
          local rels_end_offset = read_next_value(structTree, buffer, nodes_end_offset, "rels: ")
          local ids_end_offset = read_next_value(structTree, buffer, rels_end_offset, "ids: ")
          return ids_end_offset
      elseif struct_tag == 0x44 then  --Date
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "Date at offset " .. offset)
          return read_next_value(structTree, buffer, offset+2, "days: ")
      elseif struct_tag == 0x54 then  --Time
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "Time at offset " .. offset)
          local nanos_end_offset = read_next_value(structTree, buffer, offset+2, "nanoseconds: ")
          return read_next_value(structTree, buffer, nanos_end_offset, "tz_offset_seconds: ")
      elseif struct_tag == 0x74 then  --LocalTime
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "LocalTime at offset " .. offset)
          return read_next_value(structTree, buffer, offset+2, "nanoseconds: ")
      elseif struct_tag == 0x46 then  --DateTime
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "DateTime at offset " .. offset)
          local secs_end_offset = read_next_value(structTree, buffer, offset+2, "seconds: ")
          local nanos_end_offset = read_next_value(structTree, buffer, secs_end_offset, "nanoseconds: ")
          return read_next_value(structTree, buffer, nanos_end_offset, "tz_offset_seconds: ")
      elseif struct_tag == 0x66 then  --DateTimeZoneId
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "DateTimeZoneId at offset " .. offset)
          local secs_end_offset = read_next_value(structTree, buffer, offset+2, "seconds: ")
          local nanos_end_offset = read_next_value(structTree, buffer, secs_end_offset, "nanoseconds: ")
          return read_next_value(structTree, buffer, nanos_end_offset, "tz_id: ")
      elseif struct_tag == 0x64 then  --LocalDateTime
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "LocalDateTime at offset " .. offset)
          local secs_end_offset = read_next_value(structTree, buffer, offset+2, "seconds: ")
          return read_next_value(structTree, buffer, secs_end_offset, "nanoseconds: ")
      elseif struct_tag == 0x45 then  --Duration
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "Duration at offset " .. offset)
          local months_end_offset = read_next_value(structTree, buffer, offset+2, "months: ")
          local days_end_offset = read_next_value(structTree, buffer, months_end_offset, "days: ")
          local secs_end_offset = read_next_value(structTree, buffer, days_end_offset, "seconds: ")
          return read_next_value(structTree, buffer, secs_end_offset, "nanoseconds: ")
      elseif struct_tag == 0x58 then  --Point2D
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "Point2D at offset " .. offset)
          local srid_end_offset = read_next_value(structTree, buffer, offset+2, "srid: ")
          local x_end_offset = read_next_value(structTree, buffer, srid_end_offset, "x: ")
          return read_next_value(structTree, buffer, x_end_offset, "y: ")
      elseif struct_tag == 0x59 then  --Point3D
          local structTree = subtree:add(bolt_protocol, readBuffer(buffer,offset, 1), "Point3D at offset " .. offset)
          local srid_end_offset = read_next_value(structTree, buffer, offset+2, "srid: ")
          local x_end_offset = read_next_value(structTree, buffer, srid_end_offset, "x: ")
          local y_end_offset = read_next_value(structTree, buffer, x_end_offset, "y: ")
          return read_next_value(structTree, buffer, y_end_offset, "z: ")
      else subtree:add('unsupported struct type', struct_tag )
      end
  else 
    subtree:add('error', '???')
    return offset + 1
  end
end

function readMap(buffer, subtree, map_offset, data_offset, map_size, treeFieldName)
      local mapTree = subtree:add(bolt_protocol, readBuffer(buffer,map_offset, 1), (treeFieldName or "") .. "Map[" .. map_size .. "] at offset " .. map_offset) --TODO : get full map
      local i=0
      local o=data_offset
      while i < map_size do
          --read key
          local keyTree = mapTree:add(bolt_protocol, readBuffer(buffer,map_offset, 1), "key #"..i)
          local key_end_offset = read_next_value(keyTree, buffer, o, "key: ")
          --read value
          local value_end_offset = read_next_value(keyTree, buffer, key_end_offset, "value:   ")
          o=value_end_offset
          i = i + 1
      end
      return o
end

function readList(buffer, subtree, list_offset, data_offset, list_size, treeFieldName)
  local listTree = subtree:add(bolt_protocol, readBuffer(buffer,list_offset, 1), (treeFieldName or "") .. "List[" .. list_size .. "] at offset " .. list_offset) 
  local i=0
  local o=data_offset
  while i < list_size do
      --read value
      local item_offset = read_next_value(listTree, buffer, o, "#"..i)
      o=item_offset
      i = i + 1
  end
  return o
end

function read_next_chunk(subtree, pinfo, buffer, offset)
  -- chunk is : 2 bytes for chunk header (encodes chunk size) + chunk payload + 2 bytes 00 00 for chunk termination
  -- multi-chunk messages : 2 bytes chunk1 header + chunk1 payload (+ no chunk1 termination) + 2 bytes chunk2 header + chunk2 payload + 00 00
  --bytes #1 & #2 for chunk size
  local last_chunk_termination=readBuffer(buffer, offset - 2, 2):uint()
  is_multichunk=false
  if last_chunk_termination ~= 0x0000 and offset ~= 0x0000 then
    is_multichunk=true
    -- subtree:add("read_next_chunk", "multi-chunk message: this chunk is in the same message as the previous chunk")
  end
  local size=readBuffer(buffer,offset,2):uint()
  -- subtree:add("read_next_chunk", readBuffer(buffer,offset,1) .." , ".. readBuffer(buffer,offset,2) .." , ".. readBuffer(buffer,offset,3))
  --subtree:add("size", buffer:len())
  if (offset + size + 4 > buffer:len() ) then --if chunk overlaps on next TCP frame
    subtree:add("CHUNK > TCP frame", size+4 .."+".. offset .." vs ".. buffer:len())
    pinfo.desegment_len=DESEGMENT_ONE_MORE_SEGMENT--size + 4 -- (buffer:len() - offset) +10  --extra bytes to read
    pinfo.desegment_offset=0 --offset
    return 0  --bail out ; Wireshark will pick up the remaining bytes when processing the next TCP frame
  end
  local tvb=ByteArray.tvb(readBuffer(buffer,offset, size + 4):bytes(), "BOLT Chunk at offset " .. offset) 
  local chunktree = subtree:add(bolt_protocol, readBuffer(buffer,offset, size + 4), "BOLT Chunk at offset " .. offset)
  chunktree:add(chunk_size, size)
  local fieldsCnt = 0
  local message_name = "?"
  if is_multichunk then
    message_name = "MULTI-CHUNK"
    fieldsCnt = 0
  else
    --byte #3 = bN with N : number of fields
    fieldsCnt = readBuffer(buffer, offset+2, 1):uint() - 0xb0 
    chunktree:add(fields_count, fieldsCnt)  


    --byte #4 = tag (identifies the type of message)
    local tag = readBuffer(buffer,offset+3,1):int()
    message_name = get_message_name(tag)
  end
  chunktree:add(message_tag, message_name) 
  table.insert(info, message_name) -- TODO : add extra info

	local chunk_data=""
  if (size ~= 0) and ((mode == "FULL") or (mode == "QUERY" and message_name=="RUN")) then 
    -- read values
    local i=0
    temp=''
    local field_offset = offset+4
    while i < fieldsCnt do
      local field_end_offset = read_next_value(chunktree, buffer, field_offset)
      field_offset = field_end_offset
      if (i==0) and (mode == "QUERY" and message_name=="RUN") then
          table.insert(info, "["..temp.."]")
      end
      i = i + 1
    end
    -- special values to display in info
    --if (message_name == "HELLO") then
    --  chunktree.message_tag.text
    --end
  end
  termination = readBuffer(buffer,offset + 2 + size, 2):int()
  if termination ~= 0x0000 then
    -- subtree:add("read_next_chunk", "multi-chunk message: next chunk has end of message above")
    return offset + size + 2
  end
  return offset + size + 4  -- 2-byte header + 2 zero-bytes termination
end

function websocket_unmask(byte, byte_index)
  local maskByte = ws_mask(byte_index % 4, 1)
  return bxor( byte:bitfield(0, 8), maskByte:bitfield(0, 8))
end

function bxor (a,b)
  local r = 0
  for i = 0, 31 do
    local x = a / 2 + b / 2
    if x ~= math.floor (x) then
      r = r + 2^i
    end
    a = math.floor (a / 2)
    b = math.floor (b / 2)
  end
  return math.floor(r)
end

function readBuffer(buffer, start, size)
  if ws_mask then
    --local unmasked_bytes= ByteArray.new()
    unmasked_bytes:set_size(size)
    local read_bytes= buffer(start, size)
    local i = 0
    while i < size do
      print("len:"..unmasked_bytes:len())
      unmasked_bytes:set_index(i , websocket_unmask(read_bytes:range(i, 1), start + i - ws_payload_starts_at))
      i=i+1
    end
    return unmasked_bytes:tvb("WS unmasked"):range() 
    --return ByteArray.tvb(unmasked_bytes, "WS unmasked"):range() 
  else
    return buffer(start, size)
  end
end

function analyzePayload(buffer, subtree, pinfo, ws_offset) 
  local case
  local length=buffer:len()
  if (length == (2+ws_offset) and readBuffer(buffer,0+ws_offset,2):uint() == 0x0000) then
      case="NOOP"
      subtree:add(message_tag, case) 
      pinfo.cols.info = "keep-alive"
      return case
  else
    if ((length == (20 + ws_offset)) and (readBuffer(buffer,0+ws_offset,4):uint() == 0x6060b017)) then
        case="HANDSHAKE REQUEST"
        subtree:add(message_tag, case) 
        local i=1
        while i < 5 do
          local version = readBuffer(buffer,ws_offset+ 4 * i, 4)
          if version ~= 0x00000000 then
            local major = version:range(3,1):uint()
            local minor = version:range(2,1):uint()
            subtree:add(supported_version, major .. "." .. minor)
          end
          i = i + 1
        end
        pinfo.cols.info = case
        return case
    else
      if ((length == (4 + ws_offset)) and (readBuffer(buffer,0+ws_offset,2):uint() == 0x0000)) then
          case="HANDSHAKE RESPONSE"
          subtree:add(message_tag, case) 
          local version = readBuffer(buffer,0+ws_offset, 4)
          local selected_major = version:range(3,1):uint()
          local selected_minor = version:range(2,1):uint()
          local protocolVersion = selected_major .. "." .. selected_minor
          subtree:add(selected_version, protocolVersion)
          pinfo.cols.info = case .. " BOLT " .. protocolVersion
          return case
      else
          local byte3=readBuffer(buffer, 2+ws_offset,1):uint()
          local byte4=readBuffer(buffer, 3+ws_offset,1):uint()
          local first_message_name = get_message_name(byte4)
          if (byte3 >= 0xb0 and byte3 <= 0xbf and first_message_name ~= "Unknown") then
              --REGULAR MESSAGES (BEGIN, HELLO, RUN, SUCCESS...)
              info ={} -- stores info to display about each message
              local next_offset = 0 + ws_offset
              while next_offset < length do
                  --  subtree:add("while loop", next_offset .." vs ".. length)
                   local end_offset = read_next_chunk(subtree, pinfo, buffer, next_offset)
                   if end_offset == 0 then return "SKIP" end
                   next_offset = end_offset 
              end
              -- display info summary
              pinfo.cols.info = table.concat(dedupeList(info),", ")
              return first_message_name
          else --WEBSOCKET encapsulation?
            local byte1=buffer(0,1):uint()
            if ((ws_offset==0) and (byte1 == 0x00 or byte1 == 0x02 or byte1 == 0x08 or
                                  byte1 == 0x80 or byte1 == 0x82 or byte1 == 0x88)) then
              is_websocket=true

              --WS payload may start at various offsets based on payload_len & mask bits
              local ws_payload_len=buffer(1,1):bitfield(1, 7)
              ws_payload_starts_at=0
              if ws_payload_len == 126 then
                  ws_payload_starts_at=4
              elseif ws_payload_len == 127 then
                  ws_payload_starts_at=10
              else
                  ws_payload_starts_at=2
              end 
              if buffer(1,1):bitfield(0, 1) == 1 then --MASK bit
                  ws_mask = buffer(ws_payload_starts_at,4)
                  ws_payload_starts_at = ws_payload_starts_at + 4
              end
              return analyzePayload(buffer, subtree, pinfo, ws_payload_starts_at) 
            else
              return "ERROR"
            end
          end
      end
    end
  end
end

function bolt_protocol.dissector(buffer, pinfo, tree)

  if buffer:len() == 0 then return end

  is_websocket=false
  ws_mask=null
  unmasked_bytes= ByteArray.new()
  local subtree = tree:add(bolt_protocol, buffer(), "Bolt Protocol Data".. " (" .. buffer:len() .. " bytes)")
  pinfo.cols.protocol = bolt_protocol.name
  if is_websocket then
    pinfo.cols.protocol = bolt_protocol.name .. "/ws"
  end

  if (buffer:len() ~= buffer:reported_len()) then -- packet capture may truncate TCP frames ; flag those cases
    subtree:add("TCP Frame cut-off", "has " .. buffer:len() .." out of ".. buffer:reported_len() )    
  end
  local case=analyzePayload(buffer, subtree, pinfo, 0) 
  if case == "ERROR" or case == "SKIP" then return end

end

local function heuristic_checker(buffer, pinfo, tree)
  if buffer:len() == 0 then return false end
  if ((buffer:len() == (20 )) and (readBuffer(buffer,0,4):uint() == 0x6060b017)) then
    conversation = find_or_create_conversation(pinfo);
    conversation_set_dissector(conversation, PROTOABBREV_tcp_handle);
    return true
  end
  return false
end

local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(7687, bolt_protocol)
tcp_port:add(7688, bolt_protocol)

--bolt_protocol:register_heuristic("tcp", heuristic_checker)
mode="FULL" --FULL : extract all / HEADER : only headers / QUERY : headers and RUN message (that contains the CYPHER)