bolt_protocol = Proto("Bolt",  "Bolt Protocol")


message_tag = ProtoField.string("bolt.message_tag", "messageTag", base.ASCII, "BOLT message tag")
supported_version = ProtoField.string("bolt.version", "supportedVersion", base.ASCII, "Version supported by client")
chunk = ProtoField.string("bolt.chunk", "chunk", base.ASCII, "BOLT chunk")
chunk_size = ProtoField.int32("bolt.chunk_size", "chunkSize", base.DEC)
fields_count = ProtoField.int32("bolt.fields_count", "fieldsCount", base.DEC)
record_count = ProtoField.int32("bolt.record_count", "recordCount", base.DEC)
record = ProtoField.string("bolt.record", "record", base.ASCII, "BOLT result record")

bolt_protocol.fields = {message_tag, supported_version, chunk_size, fields_count, record_count, record}

function get_message_name(tag)
  local message_name = "Unknown"

      if tag ==   1 then message_name = "HELLO"			--1
  elseif tag ==   2 then message_name = "GOODBYE"		--2
  elseif tag == 112 then message_name = "SUCCESS"		--70
  elseif tag == 113 then message_name = "RECORD"		--71 	
  elseif tag == 126 then message_name = "IGNORED"		--7e
  elseif tag == 127 then message_name = "FAILURE"		--7f
  elseif tag ==  17 then message_name = "BEGIN"			--11
  elseif tag ==  18 then message_name = "COMMIT"		--12
  elseif tag ==  19 then message_name = "ROLLBACK"		--13
  elseif tag ==  16 then message_name = "RUN"			--10 
  elseif tag ==  47 then message_name = "DISCARD"		--2f
  elseif tag ==  15 then message_name = "RESET"			--0f
  elseif tag ==  63 then message_name = "PULL" 			--3f
  end

  return message_name
end


function read_next_chunk(subtree, buffer, offset)
	local size=buffer(offset,2):uint()

	local chunktree = subtree:add(bolt_protocol, buffer(offset, size + 4), "Chunk Data at offset " .. offset)
	chunktree:add(chunk_size, size)

	local tag = buffer(offset+3,1):int()
	local message_name = get_message_name(tag)
	local chunk_data=""
  	if size ~= 0 then 
  		chunk_data= buffer(offset + 2, size):string()
  		if message_name == "RECORD" then
  			local recordCount=buffer(offset + 4, 1):uint() - 144  -- 9X for list
  			chunktree:add(record_count, recordCount)

  			local record_size=buffer(offset + 5, 1):uint() -128	  -- 8X for strings
  			local record_value=buffer(offset + 6, record_size):string()
  			chunktree:add(record, record_value) 
  		elseif message_name == "BEGIN" then
  			--map {mode=r}
  			local map_size=buffer(offset + 4, 1):uint() - 160   --a1
  			local key_size=buffer(offset + 5, 1):uint() - 128   --84
  			local key_val=buffer(offset + 6, key_size):string()   --mode
   			local value_size=buffer(offset + 6 + key_size, 1):uint() - 128   --81
  			local value_val=buffer(offset + 6 + key_size + 1, value_size):string()   --mode
  			chunktree:add(record, key_val .."=" .. value_val) 
  		elseif message_name == "RUN" then
  			--D0 xx TE XT
  			local query_size=buffer(offset + 5, 1):uint()
  			local query=buffer(offset + 6, query_size):string()
  			chunktree:add(record, "query=" .. query) 
  		else
  			chunktree:add(chunk, chunk_data)
  		end
  	end
  	local fieldsCnt = buffer(offset+2,1):uint() - 176   --bX
	chunktree:add(fields_count, fieldsCnt)  
	
	
	chunktree:add(message_tag, message_name)  
  	return offset + size + 4  -- 2-byte header + 2 zero-bytes termination
end

function bolt_protocol.dissector(buffer, pinfo, tree)
  length = buffer:len()
  if length == 0 then return end

  pinfo.cols.protocol = bolt_protocol.name

  local subtree = tree:add(bolt_protocol, buffer(), "Bolt Protocol Data")
  --print("buffer : " .. buffer(0,4):uint())
  if buffer(0,4):uint() == 0x6060b017 then 
  	subtree:add(message_tag, "CLIENT HANDSHAKE") 
  	local i=1
  	while i < 5 do
  		local version = buffer(4 * i, 4):uint()
  		if version ~= 0x00000000 then
  			local major = buffer(4 * i, 4):range(3,1):uint()
  			local minor = buffer(4 * i, 4):range(2,1):uint()
  			subtree:add(supported_version, major .. "." .. minor)
  		end
  		i = i + 1
	end
  elseif length == 4 then 
  	subtree:add(message_tag, "SERVER HANDSHAKE") 
  else
  	local next_offset = 0
  	while next_offset <  length do
	  local end_offset = read_next_chunk(subtree, buffer, next_offset)
	  next_offset = end_offset
	end

 	
  end
end

local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(7687, bolt_protocol)
