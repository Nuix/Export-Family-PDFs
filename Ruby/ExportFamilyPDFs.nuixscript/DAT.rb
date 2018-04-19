# Class to assist working with DAT loadfiles
class DAT
	NEWLINE_ESCAPE_CHAR = "\u00AE"
	QUOTE_CHAR = "\u00FE"
	DELIMITER_CHAR = ""

	def self.each(file_path,&block)
		File.open(file_path,"r:utf-8") do |file|
			headers = parse_line(file.gets)
			while line = file.gets
				values = parse_line(line)
				record = {}
				headers.size.times do |column_index|
					record[column_index] = record[headers[column_index]] = values[column_index]
				end
				yield record
			end
		end
	end

	def self.transpose_each(input_file_path,output_file_path,&block)
		if output_file_path == input_file_path
			raise "input_file_path and output_file_path must be different locations"
		end
		File.open(output_file_path,"w:utf-8") do |output_file|
			File.open(input_file_path,"r:utf-8") do |file|
				headers_line = file.gets
				headers = parse_line(headers_line)
				output_file.puts(headers_line)
				while line = file.gets
					values = parse_line(line)
					record = {}
					headers.size.times do |column_index|
						record[headers[column_index]] = values[column_index]
					end
					yield(record)
					#As of Ruby 1.9 hash returns values in insertion order!
					output_file.puts(generate_line(record.values))
				end
			end
		end
	end

	def self.parse_line(line)
		#Split on delimiter character
		#Trim quotes from values
		#Unescape newlines
		return line
			.chomp
			.split(DELIMITER_CHAR)
			.map{|c|c.gsub(/(^#{QUOTE_CHAR})|(#{QUOTE_CHAR}$)/,"")}
			.map{|c|c.gsub(/#{NEWLINE_ESCAPE_CHAR}/,"\n")}
	end

	def self.generate_line(values)
		#Escape newlines
		#Quote values
		#Join with delimiter
		return values
			.map{|c|c.gsub(/\r?\n/,NEWLINE_ESCAPE_CHAR)}
			.map{|c|"#{QUOTE_CHAR}#{c}#{QUOTE_CHAR}"}
			.join(DELIMITER_CHAR)
	end
end