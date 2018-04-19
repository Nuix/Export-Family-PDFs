Export Family PDFs
==================

**Written By**: Jason Wells

# Overview

This script provides a way to generate PDF files which are a combination of individual per item PDF files.  Files are grouped by family membership.  Items which are not a member of a family will yield a PDF with only the single item.

# Input

The script requires items to be selected before being ran or that the case contain at least one production set.

When **User Selected Items** is selected, only those items selected will be present in the combined PDFs.  This means if you do not want to include particular family members and so on, do not include those items in your selection.  This script **DOES NOT** automatically include family members, etc.

When **Use Production Set Items** is selected, all items present in a selected production set will be exported.  Note that if you wish to export PDFs which included header/footer stamping you will want to select this option.

## Main Tab

- **Use Production Set Items**: When selected, items exported will be based upon the selected production set.  Note that this option will not be listed if the current case does not have any production sets.
- **Source Production Set**: The production set containing the items you would like to export when **Use Production Set Items** is checked.
- **Use Selected Items**: When selected, the export will be performed using the items which were selected when the script was ran.  Note that this option will not be listed if items were not selected when the script was ran.
- **Export Directory**: The root directory where the final PDFs will be exported to.
- **Regenerate Stored PDFs**: If true, stored copies of PDFs in the case will be regenerated.
- **Add Bookmarks**: When checked, generated PDFs will contain bookmarks allowing a user to easy jump to each constituent item's page.
- **Output Template**: This allows you to specify a template folder the directory structure and file naming of generated PDFs.  See [Template Format](#template-format) for more details.
- **DOCID Production Set**: What production set will be used when resolving the placeholder `{docid}`.  This option will only be present if there is at least one production set in the case.
- **Import Combined PDF**: When checked, the produced combined family PDF will be imported as the stored PDF for the first item in each family.  Note that since the items included in the PDF is based upon your selection of items when running this script, this is based on position and may not necessarily be the top level item in the family if it was not selected when the script was ran.
- **Delete Temporary Exported PDFs**: The script first performs a temporary batch export of per item PDFs before combining them.  When this option is checked, the temporary export will be deleted when the script no longer needs it.  If unchecked then the temporary export will not be deleted.
- **Generate DAT**: When checked, the script will produce a Concordance DAT file at the root of the export directory containing the fields of your provided metadata profile and an additional field `PDFPATH` containing the path to the combined PDF to which the given item was exported.
- **Profile**: When **Generate DAT** is checked, this determines the metadata profile which will be exported to the DAT file for each item.

## Markupsets Tab

- **Apply Highlights**: When checked, highlights from the selected markup sets will be applied to exported PDFs.
- **Apply Redactions**: When checked, redactions from teh selected markup sets will be applied to exported PDFs.
- List of markup sets to apply when performing initial temporary PDF export.

# Template Format

The template format allows you to specify place holder values which will be substituted at run-time with appropriate values, allowing you to customize the directory and file naming logic used to generate the final combined PDF files.

A placeholder consists of a placeholder named surrounded by `{` and `}` such as `{name}`.

Item's within a group are sorted by position, this is useful to note as many placeholders resolve to values based on the first item in the group.

Note that when the resolved path for a given combined PDF points to the file that already exists, the filename will have a sequential 4 fill suffix added added to prevent overwriting previously generated PDFs.

| Placeholder           | Description                                                           |
|-----------------------|-----------------------------------------------------------------------|
| `{export_directory}`  | This will be replaced with the value provided to **Export Directory** |
| `{group_index}`       | This will be replaced with a sequential number starting at 1 which will increment by 1 for each family group PDF.  Value is formatted as a 6 digit zero filled number. |
| `{group_dir}`         | This will be replaced with the value of `{group_index}` divided by 1000 rounded down.  Value is formatted as a 4 digit zero filled number.  This is useful for creating a series of sub directories for each 1000 combined PDFs. |
| `{group_count}`       | This will be replaced with the total count of items present in the family group.  Value is formatted as a 4 digit zero filled number. |
| `{descendant_count}`  | This will be replaced with the total count of items present in the family group, minus 1.  Value is formatted as a 4 digit zero filled number. |
| `{name}`              | This will be replaced with the localised name of the first item in the family group.  Note that characters which are illegal file system characters will be removed. |
| `{md5}`               | This will be replaced with the MD5 value of the first item in the family group or `No MD5` if there is no MD5 for the first item. |
| `{guid}`              | This will be replaced with the GUID value of the first item in the family group. |
| `{path}`              | This will be replaced with the path of the first item in the family group.  The path value will not contain the evidence item name or this item's name.  Note that characters which are illegal file system characters will be removed from each path segment (path item name).  Inclusion of this value essentially reproduces the item path in the export structure. |
| `{evidence_name}`     | This will be replaced with the name of the evidence item containing the first item in the family group. |
| `{date}`              | This will be replaced with the item date of the the first item in the family group, formatted `YYYYMMdd`.  For a date of June 2, 1982 this would yield `19820602`. |
| `{kind}`              | This will be replaced with the Nuix kind name of the first item in the family group. |
| `{custodian}`         | This will be replaced with the custodian name of the first item in the family group or `No Custodian` if no custodian value has been assigned to the first item.  Note that characters which are illegal file system characters will be removed from the custodian name. |
| `{position}`          | This will be replace with the Nuix position code for the first item in the group.  Each position segment will be a 4 digit zero filled number.  For example if the first item position were `1-10-23-7` in Nuix, this would yield `0001-0010-0023-0007`. |
| `{case_name}`         | This will be replaced with the name of the current case.  Note that characters which are illegal file system characters will be removed. |
| `{docid}`             | This will be replaced with the DOCID for the first item in the group based on the production set selected in the setting **DOCID Production Set**.  If the first item is not present in the selected production set, this will yield a blank value.  Note that characters which are illegal file system characters will be removed. |

# Process

The basic workflow of the script is as follows:

1. Export PDFs and DAT for all selected items using  GUID naming to temp directory.  Temp directory will automatically be created in `_Temp_` sub directory in provided export directory.
1. Read in DAT to determine location and GUID of exported PDF files
1. Determine family groupings for selected items
1. Resolve placeholders to determine output PDF name
1. Combine earlier exported PDFs into final combined PDF, saving result to final PDF location
1. Once all PDFs have been combined, temporary PDF export directory is deleted

While the script is running a progress dialog will relay the current status of the process.  This dialog has an "Abort" button which allows you to signal to the script to abort.  When clicked and confirmed, the script will attempt to gracefully abort as soon as possible.  Note that if the intial export of the per item PDFs is occurring the script will not abort until this step has completed.  All other steps of the process should generally abort relatively quickly.