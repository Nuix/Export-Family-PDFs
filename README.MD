Export Family PDFs
==================

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0) ![This script was last tested in Nuix 8.0](https://img.shields.io/badge/Script%20Tested%20in%20Nuix-8.0-green.svg)

View the GitHub project [here](https://github.com/Nuix/Export-Family-PDFs) or download the latest release [here](https://github.com/Nuix/Export-Family-PDFs/releases).

# Overview

**Written By:** Jason Wells

This script provides a way to generate PDF files which are a combination of individual per item PDF files. Files are grouped by family membership. Items which are not a member of a family will yield a PDF with only the single item.

Note that only items which are selected when the script is ran will be included in a given PDF.  For example, if you select an email, but not its attachments, then the resulting PDF will only contain the selected email and not its attachments.  The script behaves this way, rather than resolving each item to its full family, so that you can selectively determine which family members ultimately end up in the PDF.  If you want the full families regardless, then it is recommended you make a selection, then choose "Show Families", select all the resulting items and then run this script.

# Getting Started

## Setup

Begin by downloading the latest release of this code.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

## Usage

See [help file](https://github.com/NuixSDK/Export-Family-PDFs/blob/master/Ruby/ExportFamilyPDFs.nuixscript/Help.md) for details on usage.

# License

```
Copyright 2018 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
