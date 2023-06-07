# frozen_string_literal: true

require 'fileutils'
require 'relaton/index'

t1 = Time.now
puts "Started at: #{t1}"

system('git clone https://github.com/ietf-tools/relaton-data-ieee')
FileUtils.rm_rf('data')
FileUtils.cp_r('relaton-data-ieee/data', '.')
FileUtils.rm_rf('relaton-data-ieee')

FileUtils.rm Dir.glob('index*')
index = Relaton::Index.find_or_create :ieee, file: 'index-v1.yaml'
Dir['data/*.yaml'].each do |f|
  yaml = YAML.load_file f
  docid = yaml['docid'].find { |i| i['type'] == 'IEEE' && i['primary'] == true && i['trademark'].nil? }
  index.add_or_update docid['id'], f
end
index.save

t2 = Time.now
puts "Stopped at: #{t2}"
puts "Done in: #{(t2 - t1).round} sec."
