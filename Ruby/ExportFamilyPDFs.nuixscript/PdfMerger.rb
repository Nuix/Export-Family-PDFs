#Import relevant Java classes
require 'java'
java_import java.io.FileOutputStream
java_import com.itextpdf.text.Document
java_import com.itextpdf.text.pdf.PdfCopy
java_import com.itextpdf.text.pdf.PdfReader

#This class wraps iText functionality for merging PDF files
class PdfMerger
	#Merge multiple existing PDF files into a single output file
	# output_file => String full path to output file
	# input_files => Array of string full file paths to combine
	# create_bookmarks => true/false, whether to create bookmark where each input file begins
	# bookmark_titles => optional array containing title for each bookmark to be created
	def self.merge(output_file,input_files,create_bookmarks=true,bookmark_titles=nil)
		begin
			java.io.File.new(output_file).getParentFile.mkdirs
		rescue Exception => exc
			raise "Error while creating output file directories: #{exc.message}\noutput_file: #{output_file}\ninput_files: #{input_files.join("; ")}"
		end
		document = Document.new
		output_stream = FileOutputStream.new(output_file)
		copy = PdfCopy.new(document,output_stream)
		document.open
		reader = nil
		page_offset = 0
		bookmark_data = []
		input_files.each_with_index do |input_file,input_file_index|
			reader = PdfReader.new(input_file)
			pages = reader.getNumberOfPages
			pages.times do |page_number|
				copy.addPage(copy.getImportedPage(reader,page_number+1))
			end
			copy.freeReader(reader)
			reader.close
			if create_bookmarks
				title = (input_file_index + 1).to_s
				if !bookmark_titles.nil? && input_file_index < bookmark_titles.size
					title = bookmark_titles[input_file_index]
				end
				bookmark = java.util.HashMap.new
				bookmark.put("Title",title)
				bookmark.put("Action","GoTo")
				bookmark.put("Page","#{page_offset+1} Fit")
				bookmark_data << bookmark
			end
			page_offset += pages
		end
		if create_bookmarks
			copy.setOutlines(bookmark_data)
		end
		document.close
		copy.close
		output_stream.close
	end
end