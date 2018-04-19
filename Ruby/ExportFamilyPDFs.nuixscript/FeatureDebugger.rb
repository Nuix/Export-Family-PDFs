# Used to test how script behaves when particular licence features
# are present/not present.  Doesn't magically make features actually
# available so not really as good as actually testing with the
# actual licence you want to test
class FeatureDebugger
	attr_accessor :export_legal
	attr_accessor :export_items
	attr_accessor :fast_review
	attr_accessor :production_set
	attr_accessor :analysis

	def initialize
		@export_legal = true
		@export_items = true
		@fast_review = true
		@production_set = true
		@analysis = true
	end

	def hasFeature(feature)
		case feature
		when "EXPORT_LEGAL"
			return @export_legal
		when "EXPORT_ITEMS"
			return @export_items
		when "FAST_REVIEW"
			return @fast_review
		when "PRODUCTION_SET"
			return @production_set
		when "ANALYSIS"
			return @analysis
		else
			raise "FeatureDebugger does not currently simulate feature: #{feature}"
		end
	end

	def simulate_investigator_response_licence
		@export_legal = false
		@export_items = true
		@fast_review = false
		@production_set = false
		@analysis = true
	end
end