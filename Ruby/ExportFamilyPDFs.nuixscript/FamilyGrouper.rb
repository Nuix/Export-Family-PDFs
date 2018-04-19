class FamilyGrouper
	def self.find_groups(items,&block)
		sorter = $utilities.getItemSorter
		count = 0

		# Just in case we were provided a Java Set<Item>
		family_groups = items.to_a

		# For now filter out items which have no top level item and therefore are
		# not in a family
		family_groups = family_groups.reject{|i|i.getTopLevelItem.nil?}

		# Group items by their top level item
		family_groups = family_groups.group_by{|i|i.getTopLevelItem.getGuid}

		# Get the collection of items in each group without the top level GUID key
		family_groups = family_groups.values

		# Map family groups to be in item position order
		family_groups = family_groups.map do |grp|
			sorted_grp = sorter.sortItemsByPosition(grp)
			count += grp.size
			# Report progress if we were given a block
			if block_given?
				block.call(count)
			end
			next sorted_grp
		end

		# Add all items filtered earlier for not being in a family as
		# single item groups
		family_groups += items.to_a.select{|i|i.getTopLevelItem.nil?}.map{|grp|Array(grp)}

		# Sort groups by position of first item in each group
		family_groups = family_groups.sort_by{|g|g.first.getPosition}
		
		# Return results
		return family_groups
	end
end