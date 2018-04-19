# Helper class for resolving placeholders
class PlaceholderResolver
	def initialize
		# Cache regular expressions so we only incur compilation cost
		# one time each
		@regex_cache = Hash.new{|h,k| h[k] = /\{#{k}\}/i}
		# Regex for stripping illegal file system chars
		@filename_clean_regex = /[\/\\:\*\?\"<>\|\t]+/
	end

	# Resolves placeholders in given input using placeholders hash
	# to drive placeholder names to look for and the values to substitute them with
	def resolve(input,placeholders)
		result = input
		placeholders.each do |key,value|
			regex = @regex_cache[key.downcase]
			result = result.gsub(regex,value.to_s.gsub(/\\/,"\\\\\\"))
		end
		return result
	end

	# This methos will strip illegal file system chars from input
	def filename_clean(input)
		return input.to_s.gsub(@filename_clean_regex,"")
	end
end