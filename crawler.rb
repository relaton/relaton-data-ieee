# frozen_string_literal: true

require "fileutils"
require "open3"
require "relaton/ieee/data_fetcher"

# The IEEE dataset is the private repo ietf-tools/ieee-rawbib. The Crawler
# workflow passes a PAT that can read it (repo secret IEEE_RAWBIB_TOKEN) as the
# last argument. For a local run, an existing `ieee-rawbib` (a clone or a
# symlink to one) is used as it is, and the script neither clones nor deletes it.
SOURCE = "ieee-rawbib"
# GitHub token prefixes. Without the secret, the last argument can be an
# ordinary `args` value, and that is not a token.
TOKEN = /\A(?:gh[pousr]_|github_pat_)\w+\z/

cloned = false
unless File.symlink?(SOURCE) || File.exist?(SOURCE)
  token = ARGV.last.to_s
  abort "crawler.rb: no #{SOURCE} token (secret IEEE_RAWBIB_TOKEN)" unless token.match?(TOKEN)

  url = "https://oauth2:#{token}@github.com/ietf-tools/ieee-rawbib.git"
  # `fetch` reads only the files of the checkout, so one commit is sufficient.
  # git's output can show the URL, so the token is masked before it is printed.
  output, status = Open3.capture2e("git", "clone", "--depth", "1", "--quiet", url, SOURCE)
  $stderr.print output.gsub(token, "***")
  unless status.success?
    FileUtils.rm_rf(SOURCE) # only git can have made it: it did not exist before
    abort "crawler.rb: cannot clone ietf-tools/ieee-rawbib"
  end
  cloned = true
end

begin
  # Only now, with the source present, delete the old data: a failed clone must
  # not commit an empty dataset.
  FileUtils.rm_rf("data")
  # index-v1 is not built again: the v2 reader reads index-v2 from this branch.
  FileUtils.rm(Dir.glob("index*"))
  Relaton::Ieee::DataFetcher.fetch
  # A source with no usable file gives an empty data/. Fail the job, so that the
  # shared workflow does not commit the deletion of every document.
  abort "crawler.rb: #{SOURCE} gave no documents" if Dir["data/*.yaml"].empty?

  # index-v2: pubid-structured index (`_type: pubid:ieee:*`). The support
  # crawler workflow zips every index*.yaml into the matching index*.zip.
  Relaton::Ieee::DataFetcher.build_index(dir: "data", index_file: "index-v2.yaml")
ensure
  FileUtils.rm_rf(SOURCE) if cloned
end
