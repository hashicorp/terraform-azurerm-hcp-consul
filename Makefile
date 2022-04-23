.DEFAULT_GOAL := generate_templates

generate_templates: hashicups_version module_version
	scripts/generate_ui_templates.sh

hashicups_version:
	scripts/hashicups_version.sh

module_version:
	scripts/module_version.sh
