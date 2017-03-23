#!/bin/ruby

class WriteContext
	def initialize(io)
		@io = io
		@indent_count = 0
	end
	
	def put_line(line)
		indent = "\t" * @indent_count
		@io.puts "#{indent}#{line}"
	end
	
	def put_empty_line
		@io.puts ""
	end
	
	def put_values(*vals)
		quoted = vals.collect {|v| "\"#{v}\""}
		put_line(quoted.join(" "))
	end
	
	def put_braced(header)
		put_values(header)
		put_line("{")
		@indent_count += 1
		yield
		@indent_count -= 1
		put_line("}")
	end
end

def make_path(base, path)
	if base == "."
		return path
	else
		return "#{base}/#{path}"
	end
end

class Depot
	class Mapper
		def initialize(depot, base_local, base_depot)
			@depot = depot
			@base_local = base_local
			@base_depot = base_depot
		end
		
		def file(name)
			local = make_path(@base_local, name)
			@depot.add_mapping(local, @base_depot)
		end
		
		def folder(name, recursive = false)
			local = make_path(@base_local, name)
			local += "/*"
			depot = make_path(@base_depot, name)
			@depot.add_mapping(local, depot, recursive)
		end
	end

	def initialize(id)
		@id = id
		@mappings = []
	end
	
	def mapper(base_local, base_depot)
		m = Mapper.new(self, base_local, base_depot)
		if block_given?
			yield m
		else
			return m
		end
	end
	
	def add_mapping(local_path, depot_path, rec = false)
		@mappings.push [local_path, depot_path, rec]
	end
	
	def write(ctx)
		ctx.put_braced("DepotBuildConfig") do
			ctx.put_values("DepotID", @id.to_s)
			write_mappings(ctx)
		end
	end
	
	def write_mappings(ctx)
		@mappings.each do |m|
			ctx.put_empty_line
			ctx.put_braced("FileMapping") do
				ctx.put_values("LocalPath", m[0])
				ctx.put_values("DepotPath", m[1])
				ctx.put_values("recursive", "1") if m[2]
			end
		end
	end
end

if ARGV.length < 2
	puts "Usage: #{$0} [depot_desc.rb] [output_file]"
	exit(-1)
end

depot = eval(File.read(ARGV[0]))

File.open(ARGV[1], "w") do |out|
	ctx = WriteContext.new(out)
	depot.write(ctx)
end
