# frozen_string_literal: true

# Stub of Relaton::Ieee::DataFetcher for spec/crawler_spec.rb. It records the
# source files it saw, so a spec can tell which `ieee-rawbib` was read. As the
# real fetcher, it writes no document and does not fail for an empty source.
require "fileutils"

module Relaton
  module Ieee
    class DataFetcher
      def self.fetch
        files = Dir["ieee-rawbib/**/*.{xml,zip}"].sort
        return if files.empty?

        FileUtils.mkdir_p("data")
        File.write("data/new.yaml", files.join("\n"))
      end

      def self.build_index(dir:, index_file:)
        File.write(index_file, Dir["#{dir}/*.yaml"].sort.join("\n"))
      end
    end
  end
end
