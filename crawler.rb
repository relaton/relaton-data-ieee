# frozen_string_literal: true

# @TODO below is the code for local use, to be removed when https://github.com/ietf-tools/relaton-data-ieee is updated

require "relaton/ieee/data_fetcher"
FileUtils.rm_rf('data')
FileUtils.rm Dir.glob('index*')
Relaton::Ieee::DataFetcher.fetch

# End the local use code


# @TODO: uncomment everithing below when https://github.com/ietf-tools/relaton-data-ieee is updated

# require 'fileutils'
# require 'relaton/index'

# system('git clone https://github.com/ietf-tools/relaton-data-ieee')
# FileUtils.rm_rf('data')
# FileUtils.cp_r('relaton-data-ieee/data', '.')
# FileUtils.rm_rf('relaton-data-ieee')

FileUtils.rm Dir.glob('index*')

# index-v1: flat index keyed on the raw docidentifier string (back-compat).
index = Relaton::Index.find_or_create :ieee, file: 'index-v1.yaml'
Dir['data/*.yaml'].each do |f|
  yaml = YAML.load_file f
  docid = yaml['docidentifier'].find { |i| i['type'] == 'IEEE' && i['primary'] == true && i['trademark'].nil? }
  index.add_or_update docid['content'], f
end
index.save

# index-v2: pubid-structured index keyed on ::Pubid::Ieee::Identifier (rows
# serialize to `_type: pubid:ieee:*`). Ids pubid can't parse/round-trip are
# skipped; a coverage summary is logged. The support crawler workflow zips every
# index*.yaml into the matching index*.zip that the read side fetches.
Relaton::Ieee::DataFetcher.build_index(dir: 'data', index_file: 'index-v2.yaml')
