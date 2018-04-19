# Menu Title: Export Family PDFs
# Needs Case: true

require_relative "Nx.jar"
java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.ChoiceDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "org.apache.commons.io.FilenameUtils"

script_directory = File.dirname(__FILE__)
load File.join(script_directory,"PdfMerger.rb")
load File.join(script_directory,"FamilyGrouper.rb")
load File.join(script_directory,"DAT.rb")
load File.join(script_directory,"PlaceholderResolver.rb")
load File.join(script_directory,"FeatureDebugger.rb")

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

require "thread"
require "fileutils"
require "json"

# Were going to be doing a ton of licence feature checks
current_licence = $utilities.getLicence

# This is here just for testing how script overall behaves when
# certain licence features are not present
debug_feature_set = false
if debug_feature_set
	puts "CURRENTLY DEBUGGING FEATURE SET"
	current_licence = FeatureDebugger.new
	current_licence.simulate_investigator_response_licence
end

# Get list of all the metadata profiles available
profile_names = $utilities.getMetadataProfileStore.getMetadataProfiles.map{|p|p.getName}
# Get list of all production set names
production_set_names = $current_case.getProductionSets.map{|ps|ps.getName}

# Make sure minimum needs for input items is met
if production_set_names.size < 1 && $current_selected_items.size < 1
	CommonDialogs.showError("This script requires that you either have some items selected or at least one production set in the current case.")
	exit 1
end

if !current_licence.hasFeature("EXPORT_ITEMS") && !current_licence.hasFeature("EXPORT_LEGAL")
	CommonDialogs.showError("The current licence does not have features 'EXPORT_LEGAL' (needed to export production sets) or "+
		"'EXPORT_ITEMS' (needed to export selected items).  Please restart script with an appropriate licence.")
	exit 1
end

# Define our custom dialog to get user input
dialog = TabbedCustomDialog.new("Export Family PDFs")
dialog.enableStickySettings(File.join(script_directory,"RecentSettings.json"))
dialog.setHelpFile(File.join(script_directory,"Help.html"))

main_tab = dialog.addTab("main_tab","Main")

# Controls to determine input items
if current_licence.hasFeature("EXPORT_LEGAL")
	if production_set_names.size > 0
		main_tab.appendRadioButton("use_prod_items","Use Production Set Items","input_item_group",false)
		main_tab.appendComboBox("source_production_set_name","Source Production Set",production_set_names)
		main_tab.enabledOnlyWhenChecked("source_production_set_name","use_prod_items")
		main_tab.getControl("use_prod_items").setSelected(true)
	else
		if $current_selected_items.nil? || $current_selected_items.size < 1
			CommonDialogs.showWarning("This script requires that items are selected OR your licence has the feature 'EXPORT_LEGAL' and at least one production set.")
			exit 1
		end
	end
else
	puts "Current licence does not have feature 'EXPORT_LEGAL' so exporting of production sets is disabled"
	if $current_selected_items.nil? || $current_selected_items.size < 1
		CommonDialogs.showWarning("This script requires that items are selected OR your licence has the feature 'EXPORT_LEGAL' and at least one production set.")
		exit 1
	end
end

if current_licence.hasFeature("EXPORT_ITEMS") && $current_selected_items.size > 0
	main_tab.appendRadioButton("use_selected_items","Use Selected Items (#{$current_selected_items.size})","input_item_group",false)
	main_tab.getControl("use_selected_items").setSelected(true)
end

main_tab.appendDirectoryChooser("export_directory","Export Directory")
main_tab.appendCheckBox("regenerate_stored","Regenerate Stored PDFs",false)
main_tab.appendCheckBox("add_bookmarks","Add Bookmarks",true)
main_tab.appendTextField("output_template","Output Template","{export_directory}\\{evidence_name}\\{path}\\{name}.pdf")
if production_set_names.size > 0
	main_tab.appendComboBox("production_set_name","DOCID Production Set",production_set_names)
end

# Can only import the PDFs back in if you have the licence feature ANALYSIS
if current_licence.hasFeature("ANALYSIS")
	main_tab.appendCheckBox("import_combined_pdf","Import Combined PDF",false)
end

main_tab.appendCheckBox("delete_temp_pdfs","Delete Temporary Exported PDFs",true)

# Add options for DAT generation if licence allows it
if current_licence.hasFeature("EXPORT_LEGAL")
	main_tab.appendCheckBox("export_dat","Generate DAT",true)
	main_tab.appendComboBox("dat_profile","Profile",profile_names)
	main_tab.enabledOnlyWhenChecked("dat_profile","export_dat")
end

# Check if current licence can work with markup sets
if current_licence.hasFeature("FAST_REVIEW") && current_licence.hasFeature("PRODUCTION_SET")
	# Get list of all available markup sets
	markup_set_lookup = {}
	$current_case.getMarkupSets.sort_by{|ms|ms.getName}.each{|ms| markup_set_lookup[ms.getName] = ms}
	markups_tab = dialog.addTab("markups_tab","Markups")
	markups_tab.appendCheckBox("apply_highlights","Apply Highlights",false)
	markups_tab.appendCheckBox("apply_redactions","Apply Redactions",false)
	markups_tab.appendStringChoiceTable("markup_set_names","Markup Sets",markup_set_lookup.keys)
else
	puts "Current licence does not have feature 'FAST_REVIEW' and/or 'PRODUCTION_SET' so markups are disabled"
end

stamp_location_choices = {
	"Header Left" => "headerLeft",
	"Header Center" => "headerCentre",
	"Header Right" => "headerRight",
	"Footer Left" => "footerLeft",
	"Footer Center" => "footerCentre",
	"Footer Right" => "footerRight",
}

stamp_types = {
	"Name" => "name",
	"GUID" => "guid",
	"Document Number" => "document_number",
	"Item ID" => "item_id",
	"Produced By" => "produced_by",
	"MD5" => "md5",
	"SHA1" => "sha1",
	"SHA256" => "sha256",
	"Custom" => "custom",
}

if current_licence.hasFeature("EXPORT_LEGAL")
	stamp_types["Document ID"] = "document_id"
	stamp_types["Production Set Name"] = "production_set_name"
end

font_names = [
	"Courier New",
	"Arial",
	"Times New Roman",
	"Consolas",
]

stamping_settings = {}
if current_licence.hasFeature("PRODUCTION_SET")
	general_stamping_tab = dialog.addTab("general_stamping_tab","Stamping General")
	general_stamping_tab.appendCheckBox("header_line","Header Line",false)
	general_stamping_tab.appendCheckBox("footer_line","Footer Line",false)
	general_stamping_tab.appendCheckBox("increase_page_size","Increase Page Size",false)

	stamp_location_choices.each do |label,name|
		stamping_tab = dialog.addTab("#{name}_tab","#{label}")
		stamping_tab.appendCheckBox("#{name}_stamp","Stamp #{label}",false)
		stamping_tab.appendComboBox("#{name}_type","Type",stamp_types.keys) do
			stamping_tab.getControl("#{name}_custom").setEnabled(stamping_tab.getText("#{name}_type") == "Custom")
		end
		stamping_tab.appendTextField("#{name}_custom","Custom Value","")
		stamping_tab.getControl("#{name}_custom").setEnabled(false)
		stamping_tab.appendComboBox("#{name}_font_family","Font Family",font_names)
		stamping_tab.setText("#{name}_font_family","Courier New")
		stamping_tab.appendCheckBox("#{name}_bold","Bold",false)
		stamping_tab.appendCheckBox("#{name}_italic","Italic",false)
		stamping_tab.appendSpinner("#{name}_font_size","Font Size",8,1,64,1)
	end
end

worker_settings_tab = dialog.addTab("worker_settings_tab","Worker Settings")
worker_settings_tab.appendLocalWorkerSettings("worker_settings")

# Define dialog input validation
dialog.validateBeforeClosing do |values|
	if values["export_directory"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Export Directory'.")
		next false
	end

	if values["output_template"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Output Template'.")
		next false
	end

	if current_licence.hasFeature("EXPORT_LEGAL") && values["use_prod_items"] == false
		needs_prod_set = {}
		needs_prod_set["Document ID"] = true
		needs_prod_set["Production Set Name"] = true
		stamp_location_choices.each do |label,name|
			if values["#{name}_stamp"] && needs_prod_set[values["#{name}_type"]]
				CommonDialogs.showWarning("#{label} cannot use '#{values["#{name}_type"]}' unless item source is a production set.")
				next false
			end
		end
	end

	next true
end

# Display the dialog
dialog.display

# If they clicked okay and all was good, lets get to work
if dialog.getDialogResult == true
	values = dialog.toMap

	# Store some values in local variables so we dont
	# need to incur hash lookups repeatedly and for convenience
	export_directory = values["export_directory"]
	temp_directory = values["export_directory"].gsub(/\\$/,"")+"\\_Temp_"
	output_template = values["output_template"]
	add_bookmarks = values["add_bookmarks"]
	worker_settings = values["worker_settings"]

	# Deny importing PDF regardless of what setting may have been passed on
	# if the licence does not allow it
	import_combined_pdf = values["import_combined_pdf"]
	if !current_licence.hasFeature("ANALYSIS")
		import_combined_pdf = false
	end

	# Obtain PDF importer if we will be importing the results back into Nuix
	pdf_importer = nil
	if import_combined_pdf
		pdf_importer = $utilities.getPdfPrintImporter
	end

	# Determine if we will be exporting a DAT file based on 2 things
	# 1. Whether user asked us to
	# 2. Whether the current licence can actually export a DAT
	# We need both because it is possible for a JSON to load a setting that this
	# run did not actually present/collect from the user
	export_dat = values["export_dat"] && current_licence.hasFeature("EXPORT_LEGAL")

	# Build map to lookup items DOCID values if export legal is available and we
	# have a production set to work with
	doc_id_lookup = nil
	if current_licence.hasFeature("EXPORT_LEGAL") && !values["production_set_name"].nil?
		production_set = $current_case.findProductionSetByName(values["production_set_name"])
		doc_id_lookup = {}
		production_set.getProductionSetItems.each do |production_set_item|
			doc_id_lookup[production_set_item.getItem] = production_set_item.getDocumentNumber.toString
		end
	end

	# Only fetch profile for generating DAT if we will be generating a DAT
	if export_dat
		dat_profile = $utilities.getMetadataProfileStore.getMetadataProfile(values["dat_profile"])
	end

	# Used to synchronize thread access in batch exported callback
	semaphore = Mutex.new

	# Show our progress dialog
	ProgressDialog.forBlock do |pd|
		pd.setTitle("Export Family PDFs")
		pd.setSubProgressVisible(false)

		# If user wants a DAT file get this setup
		dat_file = nil
		if export_dat
			java.io.File.new(export_directory).mkdirs
			dat_file = File.open("#{export_directory}\\Loadfile.dat","w:utf-8")
			headers = dat_profile.getMetadata.map{|f|f.getName}
			headers << "PDFPATH"
			dat_file.puts(DAT.generate_line(headers))
		end

		# Build simple GUID only profile for temporary PDF export
		profile = $utilities.getMetadataProfileStore.createMetadataProfile
		profile = profile.addMetadata("SPECIAL","GUID")

		# Setup exporter for temporary PDF export
		exporter = $utilities.createBatchExporter(temp_directory)

		# Configure it to use worker settings specified by user
		exporter.setParallelProcessingSettings(worker_settings)

		# Add the loadfile if allowed and selected
		if export_dat
			exporter.addLoadFile("concordance",{
				"metadataProfile" => profile,
			})
		end

		# Not surprisingly we need to export PDFs
		exporter.addProduct("pdf",{
			"naming" => "guid",
			"path" => "PDFs",
			"regenerateStored" => values["regenerate_stored"],
		})

		#Can only call this if the the licence has the feature "EXPORT_LEGAL"
		if current_licence.hasFeature("EXPORT_LEGAL")
			exporter.setNumberingOptions({"createProductionSet" => false})
		end

		# Configure markup sets if licence supports and settings specify to
		if current_licence.hasFeature("FAST_REVIEW") && current_licence.hasFeature("PRODUCTION_SET") && values["markup_set_names"].size > 0
			markup_sets = values["markup_set_names"].map{|name| markup_set_lookup[name]}
			pd.logMessage("Assigning #{values["markup_set_names"].size} markup sets:")
			pd.logMessage(values["markup_set_names"].map{|name|"\t#{name}"}.join("\n"))
			pd.logMessage("Apply Redactions: #{values["apply_redactions"]}")
			pd.logMessage("Apply Highlights: #{values["apply_highlights"]}")
			exporter.setMarkupSets(markup_sets,{
				"applyRedactions" => values["apply_redactions"],
				"applyHighlights" => values["apply_highlights"],
			})
		end

		# Setup stamping if licence allows and user enabled it
		if current_licence.hasFeature("PRODUCTION_SET")
			if stamp_location_choices.values.any?{|name| values["#{name}_stamp"] == true}
				stamping = {
					"headerLine" => values["header_line"],
					"footerLine" => values["footer_line"],
					"increasePageSize" => values["increase_page_size"],
				}

				pd.logMessage("Stamping General")
				pd.logMessage("\tHeader Line: #{values["header_line"]}")
				pd.logMessage("\tFooter Line: #{values["footer_line"]}")
				pd.logMessage("\tIncrease Page Size: #{values["increase_page_size"]}")

				stamp_location_choices.each do |label,name|
					next if values["#{name}_stamp"] == false
					pd.logMessage("Configuring #{label} Stamping")
					style_info = []
					if values["#{name}_bold"] == true
						style_info << "bold"
					end
					if values["#{name}_italic"] == true
						style_info << "italic"
					end
					stamping[name] = {
						"type" => stamp_types[values["#{name}_type"]],
						"font" => {
							"family" => values["#{name}_font_family"],
							"style" => style_info,
							"size" => values["#{name}_font_size"],
						}
					}

					pd.logMessage("\tType: #{values["#{name}_type"]}")
					if stamp_types[values["#{name}_type"]] == "custom"
						stamping[name]["customText"] = values["#{name}_custom"]
						pd.logMessage("\tCustom Text: #{values["#{name}_custom"]}")
					end
					pd.logMessage("\tFont Family: #{values["#{name}_font_family"]}")
					pd.logMessage("\tFont Size: #{values["#{name}_font_size"]}")
					pd.logMessage("\tBold: #{values["#{name}_bold"]}")
					pd.logMessage("\tItalic: #{values["#{name}_italic"]}")
				end
				exporter.setStampingOptions(stamping)
			end
		else
			pd.logMessage("Current licence does not have feature 'PRODUCTION_SET' so no stamping will be configured")
		end

		# Will be used to periodically show progress
		last_progress = Time.now

		# Setup batch exporter callback
		exporter.whenItemEventOccurs do |info|
			potential_failure = info.getFailure
			if !potential_failure.nil?
				event_item = info.getItem
				pd.logMessage("Export failure for item: #{event_item.getGuid} : #{event_item.getLocalisedName}")
			end
			# Make the progress reporting have some thread safety
			semaphore.synchronize {
				pd.setMainProgress(info.getStageCount)
				if (Time.now - last_progress) > 5
					pd.setMainStatusAndLogIt("Exporting temporary PDFs: #{info.getStage}")
					last_progress = Time.now
				else
					pd.setMainStatus("Exporting temporary PDFs: #{info.getStage}")
				end
			}
		end

		pd.logMessage("Export Directory: #{export_directory}")

		# Progress dialog updates
		pd.setMainStatus("Exporting temporary PDFs...")

		# Begin exporting
		items = nil
		if !pd.abortWasRequested
			if values["use_selected_items"]
				# Configure it to use selected items
				items = $current_selected_items
				exporter.exportItems($current_selected_items.to_a)
			elsif values["use_prod_items"]
				# Configure it to use a production set's items
				source_prod_set = $current_case.findProductionSetByName(values["source_production_set_name"])
				items = source_prod_set.getItems
				exporter.exportItems(source_prod_set)
			else
				# Should never reach this, but if we do report it
				raise "No valid input items specified somehow...."
			end
			pd.setMainProgress(0,items.size)
		end

		# If user didnt abort, read dat to determine where everything is
		pdf_lookup = {}
		if !pd.abortWasRequested
			if export_dat
				DAT.each("#{temp_directory}\\loadfile.dat") do |record|
					pdf_lookup[record["GUID"]] = record["PDFPATH"]
				end
			else
				# DAT was not exported, so we gotta do this the hard way
				Dir.glob("#{temp_directory}/**/*.pdf").each do |pdf_file|
					guid = File.basename(pdf_file,".*")
					pdf_path = pdf_file.gsub("/","\\")
					pdf_lookup[guid] = pdf_path
				end
			end
		end

		# If user didnt abort, group by family membership, note this is not
		# including family members, it is grouping items based on having the
		# same top level item, items above top level will be in their own group
		if !pd.abortWasRequested
			pd.setMainStatus("Grouping selected items by family...")
			pd.setMainProgress(0,items.size)
			family_grouped = FamilyGrouper.find_groups(items) do |count|
				pd.setMainProgress(count)
			end
			pd.logMessage("Family Groups: #{family_grouped.size}")
		end

		# If user didnt abort, beging combining the previously exported PDF files
		if !pd.abortWasRequested
			# Progress dialog updates
			pd.setMainStatusAndLogIt("Generating combined PDFs...")
			pd.setMainProgress(0,family_grouped.size)

			# This will provide our template resolution
			placeholders = PlaceholderResolver.new

			# For each family group of items
			family_grouped.each_with_index do |group,group_index|
				# Each iteration we check for abort and break out of
				# loop if they aborted
				break if pd.abortWasRequested

				# Build up data for placeholder resolution then resolve
				group_first_item = group.first
				# Path has first and last items removed then each path item has
				# it's name cleaned for the file system, then names are joined
				primary_path = group_first_item.getPath.to_a
				primary_path.shift
				primary_path.pop
				primary_path = primary_path.map{|pi| placeholders.filename_clean(pi.getLocalisedName)}
				primary_path = primary_path.join("\\")
				# Determine docid
				docid = ""
				if !doc_id_lookup.nil?
					docid = doc_id_lookup[group_first_item] || ""
				end

				# Build hash with placeholder data for this group
				placeholder_data = {
					"export_directory" => export_directory,
					"group_index" => (group_index + 1).to_s.rjust(6,"0"),
					"group_dir" => (group_index / 1000).floor.to_s.rjust(4,"0"),
					"group_count" => group.size.to_s.rjust(4,"0"),
					"descendant_count" => (group.size - 1).to_s.rjust(4,"0"),
					"name" => placeholders.filename_clean(group_first_item.getLocalisedName),
					"md5" => (group_first_item.getDigests.getMd5 || "No MD5"),
					"guid" => group_first_item.getGuid,
					"path" => primary_path,
					"evidence_name" => placeholders.filename_clean(group_first_item.getRoot.getName),
					"kind" => group_first_item.getType.getKind.getName,
					"custodian" => placeholders.filename_clean(group_first_item.getCustodian || "No Custodian"),
					"position" => group_first_item.getPosition.toArray.to_a.map{|i|i.to_s.rjust(4,"0")}.join("-"),
					"case_name" => placeholders.filename_clean($current_case.getName),
					"docid" => placeholders.filename_clean(docid),
				}

				# Handle items without an ItemDate (likely mime-type:"application/vnd.nuix-evidence")
				if !group_first_item.getDate.nil?
					placeholder_data["date"] = group_first_item.getDate.toString("YYYYMMdd")
				else
					placeholder_data["date"]= "NoItemDate"
				end

				# Resolve placeholder values to file name
				output_file = placeholders.resolve(output_template,placeholder_data)

				# Resolve overwrite conflicts
				final_output_file = output_file
				j_output_file = java.io.File.new(final_output_file)
				conflict_index = 1
				while j_output_file.exists
					final_output_file = FilenameUtils.removeExtension(output_file) + "_" + conflict_index.to_s.rjust(4,"0") +".pdf"
					j_output_file = java.io.File.new(final_output_file)
					conflict_index += 1
				end

				# Progress dialog updates
				pd.setMainProgress(group_index+1)
				pd.setSubStatus("Group #{group_index+1}/#{family_grouped.size}")

				# Merge the PDFs
				# Depending on whether we used DAT for paths or found them manually we
				# determine the paths a little differently
				input_files = nil
				if export_dat
					input_files = group.map{|i|"#{temp_directory}\\#{pdf_lookup[i.getGuid]}"}
				else
					input_files = group.map{|i|pdf_lookup[i.getGuid]}
				end
				pd.logMessage("Merging #{group.size} PDFs into single PDF: #{final_output_file}")
				pd.logMessage("\tOutput filename modified to prevent overwriting existing combined PDF.") if final_output_file != output_file
				PdfMerger.merge(final_output_file,input_files,add_bookmarks,group.map{|i|i.getLocalisedName})

				# Import back in if specified to do so
				if import_combined_pdf
					pdf_importer.importItem(group_first_item,final_output_file)
				end

				# If we're exporting a DAT file, write out records for all members of this group
				if export_dat
					group.each do |group_item|
						dat_values = dat_profile.getMetadata.map{|f|f.evaluate(group_item)}
						dat_values << final_output_file.gsub(export_directory,"")
						dat_file.puts(DAT.generate_line(dat_values))
					end
				end
			end
		end

		# If we were exporting a DAT file, close it out as we are done with it now
		if export_dat
			dat_file.close
		end

		# Delete temp directory, note that we do this regardless of whether user aborted or not
		if values["delete_temp_pdfs"]
			pd.setMainStatusAndLogIt("Deleting PDF temp directory...")
			org.apache.commons.io.FileUtils.deleteDirectory(java.io.File.new(temp_directory))
		else
			pd.logMessage("User requested to skip deletion of temp export")
		end

		# Show feedback to user with final status
		if pd.abortWasRequested
			pd.setMainStatusAndLogIt("User Aborted")
		else
			pd.setCompleted
		end
	end
end